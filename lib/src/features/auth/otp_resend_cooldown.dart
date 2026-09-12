import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/auth/otp_request_error.dart';

/// The client half of the OTP rate limit: it stops the app from producing the
/// refusals the server guard would have to send.
///
/// The delay is always the server's own number, never a local copy of the
/// backoff table: those thresholds live in `otp_config` and move without a
/// client release. A successful send answers with the delay before a resend
/// would be accepted; a refusal carries the delay before the next attempt.
///
/// The timer is cancelled in [dispose], which is not a detail: both auth page
/// widget tests reach the OTP step, and a live timer fails them outright with
/// "A Timer is still pending".
mixin OtpResendCooldown<T extends StatefulWidget> on State<T> {
  Timer? _cooldownTimer;
  int _secondsLeft = 0;

  /// Seconds still to wait; zero when the resend button is usable.
  int get resendCooldownSeconds => _secondsLeft;

  bool get canResendOtp => _secondsLeft == 0;

  /// Starts (or restarts) the countdown. A null or non-positive [seconds]
  /// leaves the button enabled: the client never invents a delay the server
  /// did not give.
  void startResendCooldown(int? seconds) {
    _cooldownTimer?.cancel();
    if (seconds == null || seconds <= 0) {
      if (mounted) setState(() => _secondsLeft = 0);
      return;
    }
    setState(() => _secondsLeft = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          timer.cancel();
        }
      });
    });
  }

  void clearResendCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    if (mounted) setState(() => _secondsLeft = 0);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

/// The user-facing sentence for a refused OTP request (U3: a kind, never a
/// technical code).
///
/// Distinct messages on purpose: "wait 60 s", "this country is not served" and
/// "the service is paused" call for three different actions, and collapsing
/// them into one generic retry line sends the user round a loop that cannot
/// succeed.
String otpRequestErrorMessage(AppLocalizations l10n, OtpRequestError error) {
  final seconds = error.retryAfterSeconds;
  switch (error.kind) {
    case OtpRequestErrorKind.backoff:
      return seconds == null
          ? l10n.authErrorOtpSend
          : l10n.otpErrorTooSoon(seconds);
    case OtpRequestErrorKind.quotaExceeded:
      // Minutes here, not seconds: an hourly or daily ceiling is counted in
      // tens of minutes, and a four-figure second count reads as noise.
      return seconds == null
          ? l10n.authErrorOtpSend
          : l10n.otpErrorQuotaExceeded((seconds + 59) ~/ 60);
    case OtpRequestErrorKind.prefixNotServed:
      return l10n.otpErrorPrefixNotServed;
    case OtpRequestErrorKind.serviceClosed:
      return l10n.otpErrorServiceClosed;
    case OtpRequestErrorKind.invalidPhone:
      return l10n.otpErrorInvalidPhone;
    case OtpRequestErrorKind.network:
      return l10n.otpErrorNetwork;
    case OtpRequestErrorKind.unknown:
      return l10n.authErrorOtpSend;
  }
}
