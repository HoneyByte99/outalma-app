// `FunctionsPhoneOtpService` invokes `CallableFunctionClient` (plain HTTP)
// internally, the same shape as `FunctionsIdentitySubmitService`: the transport
// is not unit-testable without a real Firebase app, and its request/response
// behaviour is covered on the server side by
// `functions/test/auth_phone.test.ts`.
//
// What IS unit-testable, and load-bearing, is the port's contract: whatever the
// transport throws, `request()` surfaces an `OtpRequestError`, never the raw
// exception. `flutter_test` never calls `Firebase.initializeApp`, so
// `FirebaseAuth.instance` inside `CallableFunctionClient` throws a plain
// `FirebaseException` (`core/no-app`) before any HTTP request is made: a real,
// unmocked failure that is NOT a `FirebaseFunctionsException`, which is exactly
// the shape a bare connectivity failure has. If it escaped, both auth pages
// would fall through to their generic `catch (_)` and say "an error occurred"
// where the whole point of this layer is to say which one.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/functions_phone_otp_service.dart';
import 'package:outalma_app/src/domain/auth/otp_request_error.dart';

void main() {
  test('can be constructed as const', () {
    expect(const FunctionsPhoneOtpService(), isA<FunctionsPhoneOtpService>());
  });

  test('a transport failure that is not a FirebaseFunctionsException still '
      'surfaces as an OtpRequestError, never raw', () async {
    const service = FunctionsPhoneOtpService();

    await expectLater(
      () => service.request('+221771234567'),
      throwsA(
        isA<OtpRequestError>().having(
          (e) => e.kind,
          'kind',
          OtpRequestErrorKind.unknown,
        ),
      ),
    );
  });
}
