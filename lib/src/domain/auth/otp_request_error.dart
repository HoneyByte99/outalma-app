/// Classification of a refused OTP request into an actionable kind, pure and
/// testable.
///
/// The server guard (`functions/src/otp_rate_limit.ts`) refuses with
/// `resource-exhausted` and a stable `details.code`, never with a display
/// string: the app is bilingual and composes its own message. Branching on the
/// coarse HTTP code alone would collapse "wait 60 s", "this country is not
/// served" and "the service is closed for the day" into one sentence, and two
/// of those three are not something the user can retry out of.
///
/// Kept free of Firebase types so it unit-tests with plain values; pulling
/// `details.code` out of a `FirebaseFunctionsException` is the data adapter's
/// job (same split as [classifyIdentitySubmitError]).
library;

enum OtpRequestErrorKind {
  /// Too soon after the previous send. Carries [OtpRequestError.retryAfterMs].
  backoff,

  /// Hourly or daily ceiling for this number. Also carries a delay.
  quotaExceeded,

  /// The product does not serve this dial code.
  prefixNotServed,

  /// The service-wide daily ceiling: nobody gets a code until tomorrow. Not a
  /// countdown, and not the user's doing.
  serviceClosed,

  /// The number was rejected before the guard (not E.164, wrong channel).
  invalidPhone,

  /// Network cut or transport failure: retryable as is.
  network,

  /// Anything unmapped: a generic, non-technical retry message (U3).
  unknown,
}

class OtpRequestError implements Exception {
  const OtpRequestError(this.kind, {this.retryAfterMs});

  final OtpRequestErrorKind kind;

  /// Server-computed delay before another attempt. The client never estimates
  /// it: absent means absent, and the UI then falls back to a message without a
  /// countdown rather than inventing a number.
  final int? retryAfterMs;

  /// [retryAfterMs] rounded UP to whole seconds, which is what a countdown
  /// shows. Rounding down would re-enable the button a fraction early and
  /// manufacture the refusal this brake exists to avoid.
  int? get retryAfterSeconds =>
      retryAfterMs == null ? null : (retryAfterMs! + 999) ~/ 1000;

  @override
  String toString() =>
      'OtpRequestError(${kind.name}, retryAfterMs: $retryAfterMs)';
}

/// Classifies a refusal from its stable [detailsCode] (preferred) or its coarse
/// [httpCode] (fallback). [retryAfterMs] is read straight from the server.
OtpRequestError classifyOtpRequestError({
  String? detailsCode,
  String? httpCode,
  int? retryAfterMs,
}) {
  // Stable identifier first, so rewording a server message never reroutes the
  // flow. These strings are the OTP_ERROR map of otp_rate_limit.ts.
  switch (detailsCode) {
    case 'otp/backoff':
      return OtpRequestError(
        OtpRequestErrorKind.backoff,
        retryAfterMs: retryAfterMs,
      );
    case 'otp/window-cap':
    case 'otp/day-cap':
      return OtpRequestError(
        OtpRequestErrorKind.quotaExceeded,
        retryAfterMs: retryAfterMs,
      );
    case 'otp/prefix-not-allowed':
      return const OtpRequestError(OtpRequestErrorKind.prefixNotServed);
    case 'otp/global-cap':
      return const OtpRequestError(OtpRequestErrorKind.serviceClosed);
  }

  switch (httpCode) {
    case 'resource-exhausted':
      // A refusal by the guard whose code we could not read. Treated as a
      // quota, which is the only thing this callable exhausts; the delay is
      // shown when the server sent one.
      return OtpRequestError(
        OtpRequestErrorKind.quotaExceeded,
        retryAfterMs: retryAfterMs,
      );
    case 'invalid-argument':
      return const OtpRequestError(OtpRequestErrorKind.invalidPhone);
    case 'unavailable':
    case 'cancelled':
    case 'deadline-exceeded':
      return const OtpRequestError(OtpRequestErrorKind.network);
  }

  return const OtpRequestError(OtpRequestErrorKind.unknown);
}
