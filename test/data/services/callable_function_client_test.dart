// Tests for CallableFunctionClient.
//
// Same precedent as functions_identity_submit_service_test.dart and
// log_session_service_test.dart: `flutter_test` never calls
// `Firebase.initializeApp`, so `FirebaseAuth.instance` inside `call()` throws
// a plain `FirebaseException` (`core/no-app`) before any HTTP request is
// made. That is genuinely all that is unit-testable here without a real
// Firebase app; the request/response parsing (including the `details`
// propagation added for CADRAGE booking-ux point 3) is covered by the live
// Cloud Functions' own tests (functions/test/*.test.ts) and by every caller
// that mocks `CreateBookingUseCase`/`FunctionsIdentitySubmitService` above
// this transport.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/callable_function_client.dart';

void main() {
  test('can be constructed as const', () {
    expect(const CallableFunctionClient(), isA<CallableFunctionClient>());
  });

  test(
    'call() throws before any HTTP request without a Firebase app',
    () async {
      const client = CallableFunctionClient();
      await expectLater(
        client.call('createBooking', data: const {'providerId': 'p1'}),
        throwsA(anything),
      );
    },
  );
}
