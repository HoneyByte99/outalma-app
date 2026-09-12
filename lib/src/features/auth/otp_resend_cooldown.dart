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
    // Checked FIRST, for every path. The refusal branch of both pages calls
    // this without a `mounted` guard of its own (only their success branch has
    // one), so a user who leaves the screen while a request is in flight would
    // otherwise hit setState on a disposed State and throw out of an async gap
    // nobody catches.
    if (!mounted) return;
    if (seconds == null || seconds <= 0) {
      setState(() => _secondsLeft = 0);
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

  /// Stops the countdown outright, for a screen leaving the OTP step.
  ///
  /// UNTESTED, and knowingly so: mutation shows that removing every call to it
  /// leaves the whole suite green, because nothing observes its effect. Coming
  /// back to the OTP step always goes through a fresh send, and that send calls
  /// [startResendCooldown] again, which cancels and replaces the timer whatever
  /// state it was in. All this buys is a timer that stops ticking on a screen
  /// that no longer shows it: worth doing, not worth a test that would only
  /// assert its own setup.
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

/// Above this, a countdown is told in minutes. A ceiling refusal is tens of
/// minutes away, and "Renvoyer dans 14700s" is not a number anyone reads: the
/// snackbar next to it already says "25 min", and the two contradicting each
/// other on the same screen is worse than either alone.
const _kCountdownMinutesFrom = 120;

/// The label of the resend button while the countdown runs.
String otpResendCountdownLabel(AppLocalizations l10n, int seconds) =>
    seconds >= _kCountdownMinutesFrom
    ? l10n.otpResendInMinutes(_toMinutes(seconds))
    : l10n.otpResendIn(seconds);

/// Rounds UP, like every other delay in this flow: a minute told short would
/// re-enable the button straight into the refusal.
int _toMinutes(int seconds) => (seconds + 59) ~/ 60;

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
          : l10n.otpErrorQuotaExceeded(_toMinutes(seconds));
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
