/// Length of the phone verification code the server issues via Twilio
/// Verify (`functions/src/auth_phone.ts`, `assertCode`): the default Twilio
/// code length, tightened server-side to exactly 6 digits to shrink the
/// brute-force space. The client trusts this value to auto-submit the code
/// the moment it is fully typed or autofilled, instead of waiting on a
/// return key that numeric iOS keyboards do not have.
const otpCodeLength = 6;
