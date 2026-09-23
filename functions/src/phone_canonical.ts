// ---------------------------------------------------------------------------
// The canonical phone number
// ---------------------------------------------------------------------------
//
// The phone number is the identity of a phone account: Firebase Auth keys the
// account on it, Twilio texts it, the quota counts it. So every one of the
// three phone callables turns what the caller typed into ONE string, here,
// before anything else sees it. Start and Check then always receive the same
// string, and one subscriber cannot hold two accounts by typing their number
// two ways.
//
// The app composes the same string itself (lib/src/domain/auth/phone_number.dart),
// and both sides are pinned to shared/phone-normalisation-cases.json. The server
// still canonicalises, because apps already installed and the web front send
// whatever the user typed.

import { HttpsError } from 'firebase-functions/v2/https';
import { normalisePhone } from './otp_rate_limit';

const E164_REGEX = /^\+[1-9]\d{6,14}$/;

/// Exactly the separators PhoneField lets a user type (`[\d\s\-]`), and no
/// more: anything else is still a malformed number.
const SEPARATORS = /[\s-]/g;

/// The canonical E.164 string for [value], or `invalid-argument`.
///
/// The format is checked twice. Before: the input must look like E.164 once
/// its separators are gone. After: dropping the trunk zeros can shorten a
/// number below the E.164 minimum (`+33000000061` becomes `+3361`), and such a
/// string must not reach the quota nor Twilio.
export function canonicalPhone(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'phone must be a string');
  }
  const compact = value.trim().replace(SEPARATORS, '');
  if (!E164_REGEX.test(compact)) {
    throw new HttpsError('invalid-argument', 'phone must be in E.164 format');
  }
  const canonical = normalisePhone(compact);
  if (!E164_REGEX.test(canonical)) {
    throw new HttpsError('invalid-argument', 'phone must be in E.164 format');
  }
  return canonical;
}
