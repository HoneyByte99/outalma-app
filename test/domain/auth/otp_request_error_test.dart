// The classifier between the server guard and the two auth pages.
//
// What it protects: three of the seven kinds are NOT retryable by waiting
// (country not served, service paused, bad number). Collapsing them into one
// generic "could not send the code, please retry" would send the user round a
// loop that cannot succeed, which is exactly what both pages did before.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/auth/otp_request_error.dart';

void main() {
  group('stable details.code wins', () {
    test('maps every code the server guard can send', () {
      // Mirror of OTP_ERROR in functions/src/otp_rate_limit.ts. A code added
      // there and missed here lands in `unknown` and shows a generic message.
      const cases = <String, OtpRequestErrorKind>{
        'otp/backoff': OtpRequestErrorKind.backoff,
        'otp/window-cap': OtpRequestErrorKind.quotaExceeded,
        'otp/day-cap': OtpRequestErrorKind.quotaExceeded,
        'otp/prefix-not-allowed': OtpRequestErrorKind.prefixNotServed,
        'otp/global-cap': OtpRequestErrorKind.serviceClosed,
      };
      for (final entry in cases.entries) {
        expect(
          classifyOtpRequestError(
            detailsCode: entry.key,
            httpCode: 'resource-exhausted',
          ).kind,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('carries the delay on the two kinds that are a wait', () {
      for (final code in ['otp/backoff', 'otp/window-cap', 'otp/day-cap']) {
        expect(
          classifyOtpRequestError(
            detailsCode: code,
            retryAfterMs: 90_000,
          ).retryAfterMs,
          90_000,
        );
      }
    });

    test('carries NO delay on the two kinds that waiting cannot fix', () {
      // A countdown on "this country is not served" would promise the user
      // that waiting helps.
      for (final code in ['otp/prefix-not-allowed', 'otp/global-cap']) {
        expect(
          classifyOtpRequestError(
            detailsCode: code,
            retryAfterMs: 90_000,
          ).retryAfterMs,
          isNull,
          reason: code,
        );
      }
    });
  });

  group('fallback on the coarse HTTP code', () {
    test('an unreadable resource-exhausted is still treated as a quota', () {
      final e = classifyOtpRequestError(
        httpCode: 'resource-exhausted',
        retryAfterMs: 60_000,
      );
      expect(e.kind, OtpRequestErrorKind.quotaExceeded);
      expect(e.retryAfterMs, 60_000);
    });

    test('invalid-argument is a bad number, not a rate limit', () {
      expect(
        classifyOtpRequestError(httpCode: 'invalid-argument').kind,
        OtpRequestErrorKind.invalidPhone,
      );
    });

    test('the three transport codes are network', () {
      for (final code in ['unavailable', 'cancelled', 'deadline-exceeded']) {
        expect(
          classifyOtpRequestError(httpCode: code).kind,
          OtpRequestErrorKind.network,
          reason: code,
        );
      }
    });

    test('anything unmapped stays unknown rather than guessing', () {
      expect(
        classifyOtpRequestError(httpCode: 'internal').kind,
        OtpRequestErrorKind.unknown,
      );
      expect(classifyOtpRequestError().kind, OtpRequestErrorKind.unknown);
    });

    test('an unknown details.code does not shadow a usable http code', () {
      expect(
        classifyOtpRequestError(
          detailsCode: 'otp/something-new',
          httpCode: 'invalid-argument',
        ).kind,
        OtpRequestErrorKind.invalidPhone,
      );
    });
  });

  group('retryAfterSeconds', () {
    test('rounds UP, so the button never re-enables a fraction early', () {
      expect(
        const OtpRequestError(
          OtpRequestErrorKind.backoff,
          retryAfterMs: 59_001,
        ).retryAfterSeconds,
        60,
      );
      expect(
        const OtpRequestError(
          OtpRequestErrorKind.backoff,
          retryAfterMs: 60_000,
        ).retryAfterSeconds,
        60,
      );
    });

    test('names its kind when printed, so a log says which guard bit', () {
      expect(
        const OtpRequestError(OtpRequestErrorKind.serviceClosed).toString(),
        contains('serviceClosed'),
      );
    });

    test('an absent delay stays absent, never becomes zero', () {
      // Zero would read as "retry now" and the UI would show no countdown at
      // all where it should have shown a message without one.
      expect(
        const OtpRequestError(OtpRequestErrorKind.unknown).retryAfterSeconds,
        isNull,
      );
    });
  });

  group('reading the server payload', () {
    test('a delay arrives as an int or as a double, both usable', () {
      // The wire carries JSON numbers: the platform decides which Dart type
      // comes out, and a double falling through as null would silently disable
      // the whole mobile brake.
      expect(otpRetryAfterMs(60000), 60000);
      expect(otpRetryAfterMs(60000.0), 60000);
      expect(otpRetryAfterMs(59999.7), 59999);
    });

    test('anything not a number stays null, never a zero', () {
      // Zero reads as "retry now", the opposite of what a missing delay means.
      for (final value in <Object?>[
        null,
        '60000',
        true,
        <int>[60000],
        {},
      ]) {
        expect(otpRetryAfterMs(value), isNull, reason: '$value');
      }
    });

    test('the machine code is read only from a Map carrying a string', () {
      expect(otpDetailsCode({'code': 'otp/backoff'}), 'otp/backoff');
      expect(otpDetailsCode({'code': 42}), isNull);
      expect(otpDetailsCode({'other': 'otp/backoff'}), isNull);
      expect(otpDetailsCode('otp/backoff'), isNull);
      expect(otpDetailsCode(null), isNull);
    });

    test('a details payload that is not a Map yields no field at all', () {
      expect(otpDetailsField(null, 'retryAfterMs'), isNull);
      expect(otpDetailsField('nope', 'retryAfterMs'), isNull);
      expect(otpDetailsField({'retryAfterMs': 90000}, 'retryAfterMs'), 90000);
    });
  });
}
