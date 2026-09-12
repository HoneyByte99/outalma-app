// The sentence each refusal shows, in both shipped languages.
//
// The widget tests prove the countdown and two of the messages on the real
// screens; this covers the whole mapping, which is where the value is: the
// server has seven distinct ways to refuse and the point of the layer is that
// they do not all read as "an error occurred".
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/domain/auth/otp_request_error.dart';
import 'package:outalma_app/src/features/auth/otp_resend_cooldown.dart';

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUpAll(() async {
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('every kind has its own sentence, in both languages', () {
    for (final l10n in [fr, en]) {
      final messages = <String>{};
      for (final kind in OtpRequestErrorKind.values) {
        final message = otpRequestErrorMessage(
          l10n,
          OtpRequestError(kind, retryAfterMs: 60000),
        );
        expect(message, isNotEmpty);
        expect(
          message,
          isNot(contains('otp/')),
          reason: 'a machine code must never reach the screen (U3)',
        );
        messages.add(message);
      }
      // Seven kinds, seven distinct sentences: none of them collapses into
      // another, which is the whole reason this layer exists.
      expect(messages.length, OtpRequestErrorKind.values.length);
    }
  });

  test('the two waiting kinds use the unit that fits their scale', () {
    // 25 minutes told in seconds reads as noise; 45 seconds told in minutes
    // rounds to "1 min" and asks the user to wait 15 seconds too long.
    expect(
      otpRequestErrorMessage(
        fr,
        const OtpRequestError(OtpRequestErrorKind.backoff, retryAfterMs: 45000),
      ),
      contains('45'),
    );
    expect(
      otpRequestErrorMessage(
        fr,
        const OtpRequestError(
          OtpRequestErrorKind.quotaExceeded,
          retryAfterMs: 1500000,
        ),
      ),
      contains('25 min'),
    );
  });

  test('a waiting kind with no delay falls back to a message without one', () {
    // Rather than printing "null" or inventing a number.
    for (final kind in [
      OtpRequestErrorKind.backoff,
      OtpRequestErrorKind.quotaExceeded,
    ]) {
      final message = otpRequestErrorMessage(fr, OtpRequestError(kind));
      expect(message, fr.authErrorOtpSend);
    }
  });

  test('the two languages never return the same string for a kind', () {
    // A key present in one catalogue and absent from the other would silently
    // serve the French sentence to an English user (U4).
    for (final kind in OtpRequestErrorKind.values) {
      final error = OtpRequestError(kind, retryAfterMs: 60000);
      expect(
        otpRequestErrorMessage(fr, error),
        isNot(otpRequestErrorMessage(en, error)),
        reason: kind.name,
      );
    }
  });

  group('the countdown label', () {
    test('switches to minutes once seconds stop being readable', () {
      // A ceiling refusal is tens of minutes away. "Renvoyer dans 14700s" is
      // not a number anyone reads, and the snackbar beside it already says
      // "25 min": the two contradicting each other is worse than either alone.
      expect(otpResendCountdownLabel(fr, 60), contains('60s'));
      expect(otpResendCountdownLabel(fr, 119), contains('119s'));
      expect(otpResendCountdownLabel(fr, 1500), contains('25 min'));
      expect(otpResendCountdownLabel(en, 1500), contains('25 min'));
    });

    test('agrees with the sentence shown beside it, to the minute', () {
      // Same delay, two places on screen: they must not disagree.
      const seconds = 1500;
      expect(otpResendCountdownLabel(fr, seconds), contains('25'));
      expect(
        otpRequestErrorMessage(
          fr,
          const OtpRequestError(
            OtpRequestErrorKind.quotaExceeded,
            retryAfterMs: seconds * 1000,
          ),
        ),
        contains('25'),
      );
    });

    test('rounds minutes UP, like every other delay in this flow', () {
      // 121 s reads as 3 min, never 2: told short, the label would promise the
      // button back before the server would take the request.
      expect(otpResendCountdownLabel(fr, 121), contains('3 min'));
      expect(otpResendCountdownLabel(fr, 180), contains('3 min'));
    });
  });
}
