// Tests for LogSessionService.
//
// Covered:
//   - log(): completes without throwing when the Cloud Function call succeeds
//   - log(): swallows FirebaseFunctionsException (UNAVAILABLE) and does not
//     rethrow — session logging must never block the auth flow
//   - log(): swallows any unexpected exception

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/data/services/log_session_service.dart';

// ---------------------------------------------------------------------------
// Fakes / mocks
// ---------------------------------------------------------------------------

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<void> {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late LogSessionService service;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    service = LogSessionService(mockFunctions);

    when(() => mockFunctions.httpsCallable('logSession'))
        .thenReturn(mockCallable);
  });

  group('log()', () {
    test('completes without throwing when Cloud Function call succeeds',
        () async {
      when(() => mockCallable.call<void>(any()))
          .thenAnswer((_) async => MockHttpsCallableResult());

      await expectLater(service.log(), completes);
    });

    test(
        'swallows FirebaseFunctionsException with UNAVAILABLE code — '
        'does not rethrow', () async {
      when(() => mockCallable.call<void>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'UNAVAILABLE',
          code: 'unavailable',
        ),
      );

      // Must complete without throwing
      await expectLater(service.log(), completes);
    });

    test('swallows FirebaseFunctionsException with INTERNAL code', () async {
      when(() => mockCallable.call<void>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'INTERNAL',
          code: 'internal',
        ),
      );

      await expectLater(service.log(), completes);
    });

    test('swallows generic exceptions — does not rethrow', () async {
      when(() => mockCallable.call<void>(any()))
          .thenThrow(Exception('network error'));

      await expectLater(service.log(), completes);
    });

    test('calls httpsCallable with logSession name', () async {
      when(() => mockCallable.call<void>(any()))
          .thenAnswer((_) async => MockHttpsCallableResult());

      await service.log();

      verify(() => mockFunctions.httpsCallable('logSession')).called(1);
    });

    test('passes a map payload to the callable', () async {
      Map<String, dynamic>? capturedPayload;

      when(() => mockCallable.call<void>(any())).thenAnswer((invocation) async {
        capturedPayload =
            invocation.positionalArguments.first as Map<String, dynamic>;
        return MockHttpsCallableResult();
      });

      await service.log();

      expect(capturedPayload, isNotNull);
      expect(capturedPayload!.containsKey('platform'), isTrue);
      expect(capturedPayload!.containsKey('sessionId'), isTrue);
    });
  });
}
