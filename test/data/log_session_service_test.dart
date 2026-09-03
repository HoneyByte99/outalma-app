// Tests for LogSessionService.
//
// `LogSessionService` now invokes `CallableFunctionClient` (plain HTTP)
// internally instead of accepting an injected `FirebaseFunctions`, the same
// shape as `FunctionsIdentitySubmitService` (see
// functions_identity_submit_service_test.dart): the transport itself is not
// unit-testable without a real Firebase app, and its request/response
// behaviour is covered by the live `logSession` Cloud Function's own tests
// (functions/test/security.test.ts).
//
// What IS unit-testable, and is this class's whole contract, is that log()
// never throws: `flutter_test` never calls `Firebase.initializeApp`, so
// `FirebaseAuth.instance` inside `CallableFunctionClient` throws a plain
// `FirebaseException` (`core/no-app`) before any HTTP request is made, a
// real, unmocked exception that exercises the same swallow-everything catch
// block a genuine network failure would.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/log_session_service.dart';

void main() {
  test('can be constructed as const', () {
    expect(const LogSessionService(), isA<LogSessionService>());
  });

  test(
    'log() never throws, session logging must not block the auth flow',
    () async {
      const service = LogSessionService();
      await expectLater(service.log(), completes);
    },
  );
}
