// ---------------------------------------------------------------------------
// Phone authentication via OTP - production flow
// ---------------------------------------------------------------------------
//
// Three callable functions form the canonical phone-auth pipeline:
//
//   requestPhoneOtp({ phone })
//     → Sends an OTP via Twilio Verify. The channel is FORCED to SMS
//       server-side: any other value is refused with `invalid-argument`.
//       Rate-limited BEFORE Twilio is touched (budget line S8), so a refusal
//       costs nothing; it carries a stable `details.code` and, when the wait is
//       a wait, a `retryAfterMs`. A success carries `retryAfterMs` too: the
//       delay before a resend would be accepted.
//
//   verifyPhoneOtpAndSignIn({ phone, code })
//     → Confirms the code, returns a Firebase custom token for the existing
//       user. If no user exists for this phone, returns { newUser: true } so
//       the client can route to the sign-up screen.
//
//   verifyPhoneOtpAndSignUp({ phone, code, displayName, country, gender })
//     → Confirms the code, asserts the phone is not taken, creates the
//       Firebase Auth user (phoneNumber-native, no fake email) and the
//       Firestore user doc, returns a Firebase custom token.
//
// All three are server-authoritative: client cannot bypass uniqueness or
// claim a phone without a fresh code.

import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import { GENDERS, Gender } from './public_profiles';
import { consumeOtpQuota } from './otp_rate_limit';

const TWILIO_ACCOUNT_SID = defineSecret('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = defineSecret('TWILIO_AUTH_TOKEN');
const TWILIO_VERIFY_SERVICE_SID = defineSecret('TWILIO_VERIFY_SERVICE_SID');

/// Keys the HMAC that turns a phone number into a quota key. A bare digest
/// would be brute-forceable over the phone number space in seconds, so the
/// guard documents would be personal data barely disguised.
export const OTP_HASH_KEY = defineSecret('OTP_HASH_KEY');

const db = () => admin.firestore();

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

const E164_REGEX = /^\+[1-9]\d{6,14}$/;

function assertPhone(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'phone must be a string');
  }
  const trimmed = value.trim();
  if (!E164_REGEX.test(trimmed)) {
    throw new HttpsError('invalid-argument', 'phone must be in E.164 format');
  }
  return trimmed;
}

function assertCode(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'code must be a string');
  }
  const trimmed = value.trim();
  // Twilio Verify default code length is 6 digits. Tighten the regex to
  // exactly 6 to shrink the brute-force space (M4 from security review).
  if (!/^\d{6}$/.test(trimmed)) {
    throw new HttpsError('invalid-argument', 'code must be 6 digits');
  }
  return trimmed;
}

// Strip Unicode control + format characters (zero-width joiners, RTL overrides,
// etc.) that could bypass length checks or spoof other users' names.
const CONTROL_CHARS = /[\p{Cc}\p{Cf}]/gu;

function assertDisplayName(value: unknown, max = 80, min = 2): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'displayName must be a string');
  }
  const cleaned = value.normalize('NFC').replace(CONTROL_CHARS, '').trim();
  if (cleaned.length < min) {
    throw new HttpsError('invalid-argument', `displayName must be at least ${min} chars`);
  }
  if (cleaned.length > max) {
    throw new HttpsError('invalid-argument', 'displayName too long');
  }
  if (/[\r\n]/.test(cleaned)) {
    throw new HttpsError('invalid-argument', 'displayName must be a single line');
  }
  return cleaned;
}

/// The declared gender, MANDATORY on this path exactly as it is on the email
/// one. Rejecting the call is the point: the phone sign-up writes its own
/// `users` document server-side, so a tolerated absence here would be the one
/// way to create an account without the field and quietly reopen the hole.
///
/// Vocabulary is the client enum's, `male`/`female`, and nothing else is
/// accepted: this value ends up in a world-readable projection and is drawn as
/// a pictogram beside a person's name.
function assertGender(value: unknown): Gender {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'gender must be a string');
  }
  if (!GENDERS.includes(value as Gender)) {
    throw new HttpsError('invalid-argument', 'gender must be male or female');
  }
  return value as Gender;
}

function assertCountry(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'country must be a string');
  }
  const v = value.trim().toUpperCase();
  // For now restrict to FR / SN. Extend as the marketplace grows.
  if (v !== 'FR' && v !== 'SN') {
    throw new HttpsError('invalid-argument', 'country must be FR or SN');
  }
  return v;
}

// ---------------------------------------------------------------------------
// Twilio Verify HTTP helpers
// ---------------------------------------------------------------------------

function basicAuthHeader(sid: string, token: string): string {
  return `Basic ${Buffer.from(`${sid}:${token}`).toString('base64')}`;
}

async function postForm(
  url: string,
  auth: string,
  body: Record<string, string>
): Promise<{ status: number; json: unknown }> {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': auth,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams(body).toString(),
  });
  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    /* not JSON */
  }
  return { status: res.status, json };
}

async function twilioStartVerification(
  phone: string,
  channel: 'sms' | 'call'
): Promise<void> {
  const url = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SERVICE_SID.value()}/Verifications`;
  const auth = basicAuthHeader(
    TWILIO_ACCOUNT_SID.value(),
    TWILIO_AUTH_TOKEN.value()
  );
  const { status, json } = await postForm(url, auth, {
    To: phone,
    Channel: channel,
  });
  if (status >= 400) {
    logger.error('Twilio Verifications failed', { status, json });
    throw new HttpsError('unavailable', 'Could not send OTP');
  }
}

async function twilioCheckVerification(
  phone: string,
  code: string
): Promise<void> {
  const url = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SERVICE_SID.value()}/VerificationCheck`;
  const auth = basicAuthHeader(
    TWILIO_ACCOUNT_SID.value(),
    TWILIO_AUTH_TOKEN.value()
  );
  const { status, json } = await postForm(url, auth, {
    To: phone,
    Code: code,
  });
  if (status >= 400) {
    logger.error('Twilio VerificationCheck failed', { status, json });
    throw new HttpsError('unavailable', 'OTP verification failed');
  }
  const j = json as { status?: string; valid?: boolean };
  if (j.status !== 'approved' || j.valid !== true) {
    throw new HttpsError(
      'permission-denied',
      'Invalid or expired verification code'
    );
  }
}


// ---------------------------------------------------------------------------
// Twilio seam
// ---------------------------------------------------------------------------

/// The two Twilio calls, behind a swappable object.
///
/// `postForm` is private and not exported, so without this seam there is no way
/// to assert the claim that actually protects the money: "Twilio was NOT called
/// when the cap was reached". An unobservable claim is not a tested one. Same
/// reasoning, and same shape, as `setTextExtractor` in identity_verification.
export type TwilioClient = {
  startVerification(phone: string, channel: 'sms' | 'call'): Promise<void>;
  checkVerification(phone: string, code: string): Promise<void>;
};

const liveTwilioClient: TwilioClient = {
  startVerification: twilioStartVerification,
  checkVerification: twilioCheckVerification,
};

let activeTwilioClient: TwilioClient = liveTwilioClient;

export function setTwilioClient(client: TwilioClient): void {
  activeTwilioClient = client;
}

export function resetTwilioClient(): void {
  activeTwilioClient = liveTwilioClient;
}

// ---------------------------------------------------------------------------
// User lookup helpers - Firebase Auth is the source of truth for phone↔uid
// mapping. We DELIBERATELY do not look up via Firestore mirror, because the
// users collection allows client-side updates and could be poisoned to redirect
// sign-ins to an attacker-owned uid (cf. security review C1 / C2).
// ---------------------------------------------------------------------------

interface AuthErrorLike {
  code?: string;
}

async function findUserUidByPhone(phone: string): Promise<string | null> {
  try {
    const user = await admin.auth().getUserByPhoneNumber(phone);
    return user.uid;
  } catch (e) {
    const err = e as AuthErrorLike;
    if (err.code === 'auth/user-not-found') return null;
    throw e;
  }
}

// ---------------------------------------------------------------------------
// requestPhoneOtp
// ---------------------------------------------------------------------------

export const requestPhoneOtp = onCall(
  {
    secrets: [
      TWILIO_ACCOUNT_SID,
      TWILIO_AUTH_TOKEN,
      TWILIO_VERIFY_SERVICE_SID,
      OTP_HASH_KEY,
    ],
    region: 'us-central1',
  },
  async (request) => {
    const phone = assertPhone(request.data?.phone);

    // The channel is FORCED server-side. No surface of this product asks for
    // the voice channel (the app and the web both send 'sms'), and voice costs
    // more per verification: leaving it caller-controlled handed an attacker a
    // pricier channel at the same quota price. This endpoint is unauthenticated
    // and therefore called from outside our own interfaces by definition, so
    // "no caller asks for it" is not a reason to accept it.
    const channelRaw = request.data?.channel;
    if (channelRaw !== undefined && channelRaw !== 'sms') {
      throw new HttpsError(
        'invalid-argument',
        'channel must be sms'
      );
    }
    const channel = 'sms' as const;

    // Reserve the credit and COMMIT before touching Twilio. A Firestore
    // transaction is replayed on contention, so a network call inside it would
    // bill one SMS per replay.
    const outcome = await db().runTransaction((tx) =>
      consumeOtpQuota(db(), tx, phone, OTP_HASH_KEY.value(), Date.now())
    );

    if (!outcome.allowed) {
      // A stable machine code plus structured data, never a display string:
      // the app is bilingual and composes the message from its own catalogue.
      throw new HttpsError(
        'resource-exhausted',
        'OTP request refused by rate limit',
        { code: outcome.code, retryAfterMs: outcome.retryAfterMs }
      );
    }

    // The RAW string, deliberately. `verifyPhoneOtpAndSignIn` and
    // `verifyPhoneOtpAndSignUp` are out of this increment's scope and keep
    // sending the raw string to the Check call: Start and Check must receive
    // exactly the same string, or the user gets a billed SMS and a code that
    // can never be validated. Normalisation is a quota key and nothing else.
    await activeTwilioClient.startVerification(phone, channel);
    // `retryAfterMs` on a SUCCESS: how long before a resend would be accepted.
    // The app runs its countdown on this value rather than on a copy of the
    // backoff table, so the brake follows `otp_config` without a client release.
    return {
      sentAt: new Date().toISOString(),
      channel,
      retryAfterMs: outcome.nextRetryAfterMs,
    };
  }
);

// ---------------------------------------------------------------------------
// verifyPhoneOtpAndSignIn
// ---------------------------------------------------------------------------

export const verifyPhoneOtpAndSignIn = onCall(
  {
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SERVICE_SID],
    region: 'us-central1',
  },
  async (request) => {
    const phone = assertPhone(request.data?.phone);
    const code = assertCode(request.data?.code);

    await activeTwilioClient.checkVerification(phone, code);

    // Auth-side lookup: Firebase Auth enforces phoneNumber uniqueness, so this
    // is the only trustworthy identity resolution path.
    const uid = await findUserUidByPhone(phone);
    if (uid === null) {
      // Pad the latency a touch to make timing-based enumeration harder
      // (H2 from security review). The constant-time padding is best-effort.
      await new Promise((r) => setTimeout(r, 50));
      return { newUser: true, phoneE164: phone };
    }

    const customToken = await admin.auth().createCustomToken(uid, {
      provider: 'phone-otp',
    });

    return { newUser: false, customToken, uid };
  }
);

// ---------------------------------------------------------------------------
// verifyPhoneOtpAndSignUp
// ---------------------------------------------------------------------------

export const verifyPhoneOtpAndSignUp = onCall(
  {
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SERVICE_SID],
    region: 'us-central1',
  },
  async (request) => {
    const phone = assertPhone(request.data?.phone);
    const code = assertCode(request.data?.code);
    const displayName = assertDisplayName(request.data?.displayName);
    const country = assertCountry(request.data?.country);
    // Validated BEFORE the Twilio check, with the other arguments: a malformed
    // call must not consume the user's one-shot verification code before being
    // rejected on a field the client could have checked itself.
    const gender = assertGender(request.data?.gender);

    await activeTwilioClient.checkVerification(phone, code);

    // Auth-side uniqueness check (server-authoritative).
    if ((await findUserUidByPhone(phone)) !== null) {
      throw new HttpsError(
        'already-exists',
        'Phone number already registered'
      );
    }

    const auth = admin.auth();

    // Create Firebase Auth user with phoneNumber as the primary identifier.
    // No fake email, no deterministic password. Firebase Auth enforces phone
    // uniqueness natively - if a concurrent request beat us to it, createUser
    // throws `auth/phone-number-already-exists` which we rethrow as a clean
    // already-exists error (H3 from security review).
    let created;
    try {
      created = await auth.createUser({
        phoneNumber: phone,
        displayName,
        disabled: false,
      });
    } catch (e) {
      const err = e as AuthErrorLike;
      if (err.code === 'auth/phone-number-already-exists') {
        throw new HttpsError(
          'already-exists',
          'Phone number already registered'
        );
      }
      throw e;
    }

    const uid = created.uid;

    await db().collection('users').doc(uid).set({
      id: uid,
      displayName,
      email: '',
      phoneE164: phone,
      country,
      gender,
      activeMode: 'client',
      createdAt: admin.firestore.Timestamp.now(),
      // Consent proof (RGPD) - the sign-up screen gates submission on acceptance.
      termsAcceptedAt: admin.firestore.Timestamp.now(),
    });

    const customToken = await auth.createCustomToken(uid, {
      provider: 'phone-otp',
    });

    return { customToken, uid };
  }
);
