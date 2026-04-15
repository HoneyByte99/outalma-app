import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/booking/booking_actions.dart';

// ---------------------------------------------------------------------------
// Shared fakes (same pattern as create_booking_use_case_test)
// ---------------------------------------------------------------------------

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  _FakeCallableResult(this._data);
  final T _data;
  @override
  T get data => _data;
}

class _FakeCallable extends Fake implements HttpsCallable {
  _FakeCallable({this.shouldThrow});

  final Object? shouldThrow;
  String? capturedFunctionName;
  Map<String, Object?>? capturedPayload;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    capturedPayload = parameters as Map<String, Object?>?;
    if (shouldThrow != null) throw shouldThrow!;
    return _FakeCallableResult<T>(null as T);
  }
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this._callable);

  final _FakeCallable _callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    _callable.capturedFunctionName = name;
    return _callable;
  }
}

// ---------------------------------------------------------------------------
// AcceptBookingUseCase
// ---------------------------------------------------------------------------

void main() {
  group('AcceptBookingUseCase', () {
    test('calls acceptBooking function with bookingId', () async {
      final callable = _FakeCallable();
      final functions = _FakeFunctions(callable);
      final useCase = AcceptBookingUseCase(functions);

      await useCase('booking_123');

      expect(callable.capturedFunctionName, 'acceptBooking');
      expect(callable.capturedPayload, {'bookingId': 'booking_123'});
    });

    test('completes without error on success', () async {
      final useCase = AcceptBookingUseCase(_FakeFunctions(_FakeCallable()));
      await expectLater(useCase('booking_abc'), completes);
    });

    test('propagates FirebaseFunctionsException', () async {
      final callable = _FakeCallable(
        shouldThrow: FirebaseFunctionsException(
          message: 'permission-denied',
          code: 'permission-denied',
        ),
      );
      final useCase = AcceptBookingUseCase(_FakeFunctions(callable));

      await expectLater(
        useCase('booking_abc'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('propagates generic exception', () async {
      final callable = _FakeCallable(shouldThrow: Exception('network error'));
      final useCase = AcceptBookingUseCase(_FakeFunctions(callable));

      await expectLater(useCase('b'), throwsA(isA<Exception>()));
    });
  });

  // ---------------------------------------------------------------------------
  // RejectBookingUseCase
  // ---------------------------------------------------------------------------

  group('RejectBookingUseCase', () {
    test('calls rejectBooking function with bookingId', () async {
      final callable = _FakeCallable();
      final functions = _FakeFunctions(callable);
      final useCase = RejectBookingUseCase(functions);

      await useCase('booking_456');

      expect(callable.capturedFunctionName, 'rejectBooking');
      expect(callable.capturedPayload, {'bookingId': 'booking_456'});
    });

    test('completes without error on success', () async {
      final useCase = RejectBookingUseCase(_FakeFunctions(_FakeCallable()));
      await expectLater(useCase('booking_xyz'), completes);
    });

    test('propagates FirebaseFunctionsException', () async {
      final callable = _FakeCallable(
        shouldThrow: FirebaseFunctionsException(
          message: 'not-found',
          code: 'not-found',
        ),
      );
      final useCase = RejectBookingUseCase(_FakeFunctions(callable));

      await expectLater(
        useCase('booking_xyz'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('propagates generic exception', () async {
      final callable = _FakeCallable(shouldThrow: Exception('network error'));
      final useCase = RejectBookingUseCase(_FakeFunctions(callable));

      await expectLater(useCase('b'), throwsA(isA<Exception>()));
    });
  });
}
