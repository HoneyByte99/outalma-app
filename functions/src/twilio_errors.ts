// ---------------------------------------------------------------------------
// Reading Twilio Verify's error replies
// ---------------------------------------------------------------------------
//
// Pure: no network, no Firestore, no logger. auth_phone.ts calls Twilio and
// hands the reply here; what the caller is told is decided in this file.
//
// Before this module every reply >= 400 became `unavailable`, which the app
// shows as a network or service problem. Two of those replies are not outages
// at all, they are the user's own input, and production logs showed both.

import { HttpsError } from 'firebase-functions/v2/https';

/// The message of every "this code will not pass" refusal. One constant, so a
/// verification Twilio no longer knows reads EXACTLY like a wrong code: the
/// answer must not reveal whether a verification is pending for a number.
export const INVALID_OR_EXPIRED_CODE = 'Invalid or expired verification code';

/// Twilio's numeric error code, when the reply carries one.
function twilioCode(json: unknown): number | null {
  if (typeof json !== 'object' || json === null) return null;
  const code = (json as { code?: unknown }).code;
  return typeof code === 'number' ? code : null;
}

/// Check codes meaning the verification can no longer be approved: 20404, the
/// verification is gone (expired after ten minutes, already approved, or
/// deleted after too many attempts); 60202, the attempts are spent. Either
/// way the user needs a new code, which is what "invalid or expired" tells them.
const CHECK_GONE_CODES: readonly number[] = [20404, 60202];

/// The error a failed VerificationCheck (HTTP status >= 400) turns into.
export function checkFailure(status: number, json: unknown): HttpsError {
  const code = twilioCode(json);
  if (status === 404 || (code !== null && CHECK_GONE_CODES.includes(code))) {
    return new HttpsError('permission-denied', INVALID_OR_EXPIRED_CODE);
  }
  return new HttpsError('unavailable', 'OTP verification failed');
}

/// Start codes meaning the number itself will not receive our SMS: 60200, an
/// invalid parameter (the channel is forced to `sms` server-side, so `To` is
/// the only parameter a caller controls); 60205, a landline that cannot take
/// an SMS. The app shows `invalid-argument` as "this number is not valid".
const START_BAD_NUMBER_CODES: readonly number[] = [60200, 60205];

/// The error a failed Verifications call (HTTP status >= 400) turns into.
export function startFailure(status: number, json: unknown): HttpsError {
  const code = twilioCode(json);
  if (code !== null && START_BAD_NUMBER_CODES.includes(code)) {
    return new HttpsError('invalid-argument', 'phone is not a valid number');
  }
  return new HttpsError('unavailable', 'Could not send OTP');
}
