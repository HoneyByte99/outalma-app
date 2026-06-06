// ---------------------------------------------------------------------------
// Phone authentication via OTP — production flow
// ---------------------------------------------------------------------------
//
// Three callable functions form the canonical phone-auth pipeline:
//
//   requestPhoneOtp({ phone, channel? })
//     → Sends an OTP via Twilio Verify on the requested channel (sms|call).
//
//   verifyPhoneOtpAndSignIn({ phone, code })
//     → Confirms the code, returns a Firebase custom token for the existing
//       user. If no user exists for this phone, returns { newUser: true } so
//       the client can route to the sign-up screen.
//
//   verifyPhoneOtpAndSignUp({ phone, code, displayName, country })
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

const TWILIO_ACCOUNT_SID = defineSecret('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = defineSecret('TWILIO_AUTH_TOKEN');
const TWILIO_VERIFY_SERVICE_SID = defineSecret('TWILIO_VERIFY_SERVICE_SID');

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
// User lookup helpers — Firebase Auth is the source of truth for phone↔uid
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
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SERVICE_SID],
    region: 'us-central1',
  },
  async (request) => {
    const phone = assertPhone(request.data?.phone);
    const channelRaw = request.data?.channel;
    const channel: 'sms' | 'call' =
      channelRaw === 'call' ? 'call' : 'sms';

    await twilioStartVerification(phone, channel);
    return { sentAt: new Date().toISOString(), channel };
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

    await twilioCheckVerification(phone, code);

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

    await twilioCheckVerification(phone, code);

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
    // uniqueness natively — if a concurrent request beat us to it, createUser
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
      activeMode: 'client',
      createdAt: admin.firestore.Timestamp.now(),
      // Consent proof (RGPD) — the sign-up screen gates submission on acceptance.
      termsAcceptedAt: admin.firestore.Timestamp.now(),
    });

    const customToken = await auth.createCustomToken(uid, {
      provider: 'phone-otp',
    });

    return { customToken, uid };
  }
);
