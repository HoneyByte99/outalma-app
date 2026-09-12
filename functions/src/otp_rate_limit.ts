// ---------------------------------------------------------------------------
// OTP rate limiting - pure decision logic
// ---------------------------------------------------------------------------
//
// `requestPhoneOtp` is unauthenticated and calls Twilio Verify, a billed API,
// on every invocation. Budget line S8: "an uncapped callable in front of a
// billed API is a denial of service against ourselves". This module holds
// every decision that guards that spend, with NO Firestore and NO network, so
// each rule is testable by table and killable by mutation.
//
// Three dimensions, because a per-number cap alone does not bound the spend:
// SMS pumping uses thousands of distinct numbers, so the attacker simply moves
// on. Hence a dial-code allowlist (which removes the expensive destinations)
// and a global daily ceiling (which bounds the worst day) on top of it.
//
// Deliberately NOT a per-IP dimension: Senegalese carrier-grade NAT puts
// thousands of subscribers behind one public address, so an IP counter would
// block real users long before an attacker, who changes address for free.

import { createHmac } from 'crypto';

// ---------------------------------------------------------------------------
// Dial codes
// ---------------------------------------------------------------------------

/// The dial codes the product actually offers. Kept in sync with the mobile
/// picker (`lib/src/features/shared/phone_field.dart`) by a parity test on both
/// sides, against `shared/allowed-phone-prefixes.json`.
///
/// This is a TypeScript constant and NOT a JSON file read at runtime, and that
/// is not a style choice: `firebase.json` uploads only the `functions/`
/// directory, so anything under `app/shared/` is absent from the deployed
/// bundle. A `readFileSync` here would throw ENOENT at module load and take
/// the three phone callables down with it.
export const ALLOWED_PREFIXES: readonly string[] = [
  '+1',
  '+212',
  '+213',
  '+216',
  '+221',
  '+223',
  '+224',
  '+225',
  '+226',
  '+227',
  '+228',
  '+229',
  '+237',
  '+32',
  '+33',
  '+34',
  '+351',
  '+352',
  '+39',
  '+41',
  '+44',
  '+49',
];

/// Dial codes whose national numbers carry a trunk prefix `0` that is dropped
/// in international format. ONLY these strip a leading zero.
///
/// Every entry was checked against a real number of the country rather than
/// assumed. Two traps this table exists to avoid:
///
///   +39 (Italy) is ABSENT on purpose: the leading zero is part of the number
///   there (a Rome landline is +39 06...). Stripping it would map two distinct
///   subscribers onto one quota key.
///
///   +216 (Tunisia) is ABSENT too: Tunisian numbers start with 2, 4, 5 or 9
///   and the country has no trunk prefix at all, so the rule would never fire.
///
/// West African codes (+221 +223..+229 +237), +34, +351, +352 and +1 have no
/// trunk prefix either.
export const TRUNK_ZERO_PREFIXES: readonly string[] = [
  '+212',
  '+213',
  '+32',
  '+33',
  '+41',
  '+44',
  '+49',
];

/// Longest first, so `+221` is never shadowed by a shorter sibling.
function longestPrefixMatch(
  phone: string,
  prefixes: readonly string[]
): string | null {
  let best: string | null = null;
  for (const p of prefixes) {
    if (phone.startsWith(p) && (best === null || p.length > best.length)) {
      best = p;
    }
  }
  return best;
}

export function isAllowedPrefix(phone: string): boolean {
  return longestPrefixMatch(phone, ALLOWED_PREFIXES) !== null;
}

/// Quota key normalisation, and NOTHING ELSE.
///
/// This value never reaches Twilio. `requestPhoneOtp` sends the RAW string,
/// because `verifyPhoneOtpAndSignIn` / `verifyPhoneOtpAndSignUp` are out of
/// this increment's scope and keep sending the raw string to the Check call:
/// normalising only the Start would hand Twilio `+33612345678` at Start and
/// `+330612345678` at Check, so the user would get a billed SMS and a code
/// that can never be validated.
///
/// The only job here is that one subscriber cannot hold two quotas by typing
/// their number two ways. Every leading zero of the national part is dropped,
/// not just the first, so stacked variants (`+3300612…`) collapse onto the same
/// key. No real subscriber of these countries has a national number starting
/// with zero, so the mapping never merges two distinct people.
export function normalisePhone(phone: string): string {
  const prefix = longestPrefixMatch(phone, TRUNK_ZERO_PREFIXES);
  if (prefix === null) return phone;
  const national = phone.slice(prefix.length);
  const stripped = national.replace(/^0+/, '');
  // Never return a bare dial code: a string of zeros is malformed input, and
  // collapsing it to the prefix would put every such attempt on one key.
  if (stripped.length === 0) return phone;
  return `${prefix}${stripped}`;
}

// ---------------------------------------------------------------------------
// Day key
// ---------------------------------------------------------------------------

/// `YYYY-MM-DD` in Europe/Paris, the timezone every scheduled function of this
/// project already uses. Pure and testable: the global counter document id
/// depends on it, so a drifting definition would silently split a day in two.
export function dayKey(nowMs: number): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(nowMs));
  // en-CA already yields YYYY-MM-DD.
  return parts;
}

// ---------------------------------------------------------------------------
// State and limits
// ---------------------------------------------------------------------------

/// The guard document, one per normalised phone hash.
///
/// Deviation from the approved plan, deliberate: the plan also stored
/// `lastSentAtMs` and `consecutiveSends`. Both are DERIVED from the timestamp
/// array (the last element, and the number of entries inside the window), and
/// storing a derived value is how the two copies end up disagreeing. They are
/// computed instead.
export type OtpState = {
  creditTimestampsMs: number[];
  updatedAtMs: number;
};

export type OtpLimits = {
  backoffMs: number[];
  maxPerWindow: number;
  windowMs: number;
  maxPerDay: number;
  dayWindowMs: number;
  alertAt: number;
  stopAt: number;
};

/// Approved by Amath on 2026-09-12, with the spend they authorise written in
/// the plan. Twilio Verify bills ~0.05 USD per SUCCESSFUL verification plus a
/// channel fee per message SENT; an attacker never validates, so only the
/// channel fee applies and the stop threshold is what bounds the worst day.
export const DEFAULT_LIMITS: OtpLimits = {
  backoffMs: [60_000, 120_000, 300_000],
  maxPerWindow: 6,
  windowMs: 60 * 60 * 1000,
  maxPerDay: 15,
  dayWindowMs: 24 * 60 * 60 * 1000,
  alertAt: 300,
  stopAt: 600,
};

/// How long a guard document is kept (budget line S11). MUST stay strictly
/// greater than `dayWindowMs`, otherwise the purge would erase a 24h counter
/// before it expires and hand back a fresh quota.
export const OTP_STATE_TTL_MS = 48 * 60 * 60 * 1000;

export const OTP_ERROR = {
  prefixNotAllowed: 'otp/prefix-not-allowed',
  backoff: 'otp/backoff',
  windowCap: 'otp/window-cap',
  dayCap: 'otp/day-cap',
  globalCap: 'otp/global-cap',
} as const;

export type OtpErrorCode = (typeof OTP_ERROR)[keyof typeof OTP_ERROR];

function clamp(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  if (value < min || value > max) return fallback;
  return Math.floor(value);
}

/// Thresholds may be tuned live from the `otp_config/thresholds` document,
/// because raising a ceiling during an incident must not require a deploy
/// (deploys are a manual step on this project).
///
/// Every value read from that document is bounded by code constants, and the
/// `alertAt < stopAt` invariant is enforced: an absent, malformed OR absurd
/// value (0, negative, 1e9) falls back to the default rather than disabling the
/// guard. A config document is an input, and an input that can switch off a
/// security control is not a config, it is a backdoor.
export function resolveLimits(configDoc: unknown): OtpLimits {
  const d = (configDoc ?? {}) as Record<string, unknown>;
  const alertAt = clamp(d.alertAt, 1, 100_000, DEFAULT_LIMITS.alertAt);
  const stopAt = clamp(d.stopAt, 1, 100_000, DEFAULT_LIMITS.stopAt);
  const resolved: OtpLimits = {
    ...DEFAULT_LIMITS,
    maxPerWindow: clamp(d.maxPerWindow, 1, 100, DEFAULT_LIMITS.maxPerWindow),
    maxPerDay: clamp(d.maxPerDay, 1, 1000, DEFAULT_LIMITS.maxPerDay),
    alertAt,
    stopAt,
  };
  // A stop below the alert would mean refusing before ever warning. Both fall
  // back together so the pair stays coherent.
  if (resolved.alertAt >= resolved.stopAt) {
    resolved.alertAt = DEFAULT_LIMITS.alertAt;
    resolved.stopAt = DEFAULT_LIMITS.stopAt;
  }
  return resolved;
}

/// Tolerance rule: a missing field or an unexpected type is read as an EMPTY
/// state, never as an implicit authorisation. Fail-closed on the value,
/// fail-open on the representation of emptiness.
export function readState(raw: unknown): OtpState {
  const d = (raw ?? {}) as Record<string, unknown>;
  const list = Array.isArray(d.creditTimestampsMs) ? d.creditTimestampsMs : [];
  const timestamps = list.filter(
    (t): t is number => typeof t === 'number' && Number.isFinite(t)
  );
  const updatedAtMs =
    typeof d.updatedAtMs === 'number' && Number.isFinite(d.updatedAtMs)
      ? d.updatedAtMs
      : 0;
  return { creditTimestampsMs: timestamps, updatedAtMs };
}

export type OtpDecision =
  | { allowed: true; nextState: OtpState; globalAfter: number }
  | { allowed: false; code: OtpErrorCode; retryAfterMs: number };

/// The whole guard, in one pure function.
///
/// A REFUSAL WRITES NOTHING and consumes no credit, whichever dimension
/// refuses: being turned away must not cost the caller their next legitimate
/// attempt.
export function decideOtpRequest(
  rawState: unknown,
  globalCount: number,
  phone: string,
  limits: OtpLimits,
  nowMs: number
): OtpDecision {
  if (!isAllowedPrefix(phone)) {
    return {
      allowed: false,
      code: OTP_ERROR.prefixNotAllowed,
      retryAfterMs: 0,
    };
  }

  // Global ceiling first among the counting rules: when it bites, nothing else
  // matters, and it must not be maskable by a per-number refusal.
  if (globalCount >= limits.stopAt) {
    return { allowed: false, code: OTP_ERROR.globalCap, retryAfterMs: 0 };
  }

  const state = readState(rawState);
  const inDay = state.creditTimestampsMs.filter(
    (t) => nowMs - t < limits.dayWindowMs
  );
  const inWindow = inDay.filter((t) => nowMs - t < limits.windowMs);

  if (inWindow.length > 0) {
    const lastSentAtMs = Math.max(...inWindow);
    const rank = Math.min(inWindow.length - 1, limits.backoffMs.length - 1);
    // Indexed access is checked in this project, and an empty backoff table
    // must not silently mean "no wait": fall back to the first default step.
    const wait = limits.backoffMs[rank] ?? DEFAULT_LIMITS.backoffMs[0] ?? 60_000;
    const elapsed = nowMs - lastSentAtMs;
    if (elapsed < wait) {
      return {
        allowed: false,
        code: OTP_ERROR.backoff,
        retryAfterMs: wait - elapsed,
      };
    }
  }

  if (inWindow.length >= limits.maxPerWindow) {
    const oldest = Math.min(...inWindow);
    return {
      allowed: false,
      code: OTP_ERROR.windowCap,
      retryAfterMs: limits.windowMs - (nowMs - oldest),
    };
  }

  if (inDay.length >= limits.maxPerDay) {
    const oldest = Math.min(...inDay);
    return {
      allowed: false,
      code: OTP_ERROR.dayCap,
      retryAfterMs: limits.dayWindowMs - (nowMs - oldest),
    };
  }

  return {
    allowed: true,
    nextState: {
      creditTimestampsMs: [...inDay, nowMs],
      updatedAtMs: nowMs,
    },
    globalAfter: globalCount + 1,
  };
}

// ---------------------------------------------------------------------------
// Hashing
// ---------------------------------------------------------------------------

/// HMAC-SHA256 of the NORMALISED number, never the number itself.
///
/// A bare SHA-256 would not do: the phone number space is small enough to
/// exhaust in seconds, so an unkeyed digest is personal data barely disguised.
/// The key makes the mapping underivable outside the server.
///
/// An absent or empty key throws rather than degrading to something weaker.
/// That is the whole point of the guard: a silent fallback would reintroduce
/// exactly the weakness this is here to close.
export function phoneHash(phone: string, key: string): string {
  if (typeof key !== 'string' || key.trim().length === 0) {
    throw new Error('OTP_HASH_KEY is missing: refusing to hash without a key.');
  }
  return createHmac('sha256', key).update(normalisePhone(phone)).digest('hex');
}
