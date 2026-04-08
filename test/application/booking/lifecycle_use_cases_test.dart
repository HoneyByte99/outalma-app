import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/booking/booking_actions.dart';

// ---------------------------------------------------------------------------
// Shared fakes (same pattern throughout the test suite)
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
  String? capturedName;
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
    _callable.capturedName = name;
    return _callable;
  }
}

// Helper: build a use case around a fresh callable that may throw
_FakeCallable _callable({Object? throws}) => _FakeCallable(shouldThrow: throws);
_FakeFunctions _fns(_FakeCallable c) => _FakeFunctions(c);

// ---------------------------------------------------------------------------
// MarkInProgressUseCase
// ---------------------------------------------------------------------------

void main() {
  group('MarkInProgressUseCase', () {
    test('calls markInProgress with bookingId', () async {
      final c = _callable();
      await MarkInProgressUseCase(_fns(c))('booking_1');
      expect(c.capturedName, 'markInProgress');
      expect(c.capturedPayload, {'bookingId': 'booking_1'});
    });

    test('completes without error on success', () async {
      await expectLater(
        MarkInProgressUseCase(_fns(_callable()))('bk'),
        completes,
      );
    });

    test('propagates FirebaseFunctionsException', () async {
      final c = _callable(
        throws: FirebaseFunctionsException(
          message: 'failed-precondition',
          code: 'failed-precondition',
        ),
      );
      await expectLater(
        MarkInProgressUseCase(_fns(c))('bk'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('propagates generic exception', () async {
      final c = _callable(throws: Exception('network'));
      await expectLater(
        MarkInProgressUseCase(_fns(c))('bk'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ConfirmDoneUseCase
  // ---------------------------------------------------------------------------

  group('ConfirmDoneUseCase', () {
    test('calls confirmDone with bookingId', () async {
      final c = _callable();
      await ConfirmDoneUseCase(_fns(c))('booking_2');
      expect(c.capturedName, 'confirmDone');
      expect(c.capturedPayload, {'bookingId': 'booking_2'});
    });

    test('completes without error on success', () async {
      await expectLater(
        ConfirmDoneUseCase(_fns(_callable()))('bk'),
        completes,
      );
    });

    test('propagates FirebaseFunctionsException', () async {
      final c = _callable(
        throws: FirebaseFunctionsException(
          message: 'permission-denied',
          code: 'permission-denied',
        ),
      );
      await expectLater(
        ConfirmDoneUseCase(_fns(c))('bk'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('propagates generic exception', () async {
      final c = _callable(throws: Exception('timeout'));
      await expectLater(
        ConfirmDoneUseCase(_fns(c))('bk'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CancelBookingUseCase
  // ---------------------------------------------------------------------------

  group('CancelBookingUseCase', () {
    test('calls cancelBooking with bookingId', () async {
      final c = _callable();
      await CancelBookingUseCase(_fns(c))('booking_3');
      expect(c.capturedName, 'cancelBooking');
      expect(c.capturedPayload, {'bookingId': 'booking_3'});
    });

    test('completes without error on success', () async {
      await expectLater(
        CancelBookingUseCase(_fns(_callable()))('bk'),
        completes,
      );
    });

    test('propagates FirebaseFunctionsException', () async {
      final c = _callable(
        throws: FirebaseFunctionsException(
          message: 'not-found',
          code: 'not-found',
        ),
      );
      await expectLater(
        CancelBookingUseCase(_fns(c))('bk'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('propagates generic exception', () async {
      final c = _callable(throws: Exception('offline'));
      await expectLater(
        CancelBookingUseCase(_fns(c))('bk'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
