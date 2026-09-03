import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/functions_identity_submit_service.dart';
import 'package:outalma_app/src/domain/identity/identity_submit_error.dart';

// `FunctionsIdentitySubmitService` now invokes `CallableFunctionClient` (plain
// HTTP) internally instead of accepting an injected `FirebaseFunctions`, the
// same shape as `CreateBookingUseCase` (see create_booking_use_case_test.dart):
// the transport itself is not unit-testable without a real Firebase app, and
// its request/response behaviour is covered by integration tests against the
// live `submitIdentityVerification` Cloud Function.
//
// What IS unit-testable, and load-bearing, is the port's contract: whatever
// the transport throws, `submit()` must surface an `IdentitySubmitError`,
// never the raw exception. `flutter_test` never calls `Firebase.initializeApp`,
// so `FirebaseAuth.instance` inside `CallableFunctionClient` throws a plain
// `FirebaseException` (`core/no-app`) before any HTTP request is made - a
// real, unmocked exception that is NOT a `FirebaseFunctionsException`, i.e.
// exactly the shape the crash fix (identity-submit-crash) had to catch: the
// native iOS SDK's Swift concurrency fatalError and a bare connectivity
// failure share that same "not a FirebaseFunctionsException" shape.
void main() {
  test('can be constructed as const', () {
    expect(
      const FunctionsIdentitySubmitService(),
      isA<FunctionsIdentitySubmitService>(),
    );
  });

  test('a transport failure that is not a FirebaseFunctionsException still '
      'surfaces as an IdentitySubmitError, never raw', () async {
    const service = FunctionsIdentitySubmitService();

    await expectLater(
      () => service.submit(batchId: 'batch0001'),
      throwsA(
        isA<IdentitySubmitError>().having(
          (e) => e.kind,
          'kind',
          IdentitySubmitErrorKind.unknown,
        ),
      ),
    );
  });
}
