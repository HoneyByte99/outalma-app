/// The seam between the auth pages and the `requestPhoneOtp` callable.
///
/// A thin interface so a widget test can stand in for the network, and so the
/// UI never touches a Firebase type: implementations translate a
/// `FirebaseFunctionsException` into an `OtpRequestError` and throw that.
library;

/// What a successful send tells the client.
class OtpRequestOutcome {
  const OtpRequestOutcome({required this.retryAfterMs});

  /// Server-computed delay before a resend would be accepted, which the resend
  /// countdown runs on. The client never derives it from a local copy of the
  /// backoff table: those thresholds live in `otp_config` and can move without
  /// a client release.
  ///
  /// Null when the server did not send one (an older deployed build, or the
  /// service-wide ceiling reached on this very request). The UI then leaves the
  /// resend button enabled rather than inventing a delay.
  final int? retryAfterMs;

  /// [retryAfterMs] rounded UP to whole seconds. Rounding down would re-enable
  /// the button a fraction early, straight into a refusal.
  int? get retryAfterSeconds =>
      retryAfterMs == null ? null : (retryAfterMs! + 999) ~/ 1000;
}

/// Calls `requestPhoneOtp({phone})`. Throws `OtpRequestError` and nothing else.
abstract interface class PhoneOtpPort {
  Future<OtpRequestOutcome> request(String phoneE164);
}
