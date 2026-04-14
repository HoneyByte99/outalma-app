import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/booking/create_booking_use_case.dart';

// ---------------------------------------------------------------------------
// Fake implementations — no mockito needed
// ---------------------------------------------------------------------------

class _FakeCallableResult implements HttpsCallableResult<Map<String, dynamic>> {
  _FakeCallableResult(this.data);

  @override
  final Map<String, dynamic> data;
}

class _FakeCallable extends Fake implements HttpsCallable {
  _FakeCallable({required this.response, this.shouldThrow});

  final Map<String, dynamic>? response;
  final Object? shouldThrow;

  Map<String, Object?>? capturedPayload;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    capturedPayload = parameters as Map<String, Object?>?;
    if (shouldThrow != null) throw shouldThrow!;
    return _FakeCallableResult(response!) as HttpsCallableResult<T>;
  }
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this._callable);

  final _FakeCallable _callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _callable;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CreateBookingUseCase', () {
    test('returns bookingId on success', () async {
      final callable = _FakeCallable(response: {'bookingId': 'booking_abc'});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      final id = await useCase(
        providerId: 'provider_1',
        serviceId: 'service_1',
        requestMessage: 'Besoin d\'aide',
      );

      expect(id, 'booking_abc');
    });

    test('payload includes required fields', () async {
      final callable = _FakeCallable(response: {'bookingId': 'booking_abc'});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await useCase(
        providerId: 'provider_1',
        serviceId: 'service_2',
        requestMessage: 'Besoin d\'aide',
      );

      final payload = callable.capturedPayload!;
      expect(payload['providerId'], 'provider_1');
      expect(payload['serviceId'], 'service_2');
      expect(payload['requestMessage'], 'Besoin d\'aide');
    });

    test('includes schedule in payload when non-empty', () async {
      final callable = _FakeCallable(response: {'bookingId': 'booking_abc'});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await useCase(
        providerId: 'p',
        serviceId: 's',
        requestMessage: 'm',
        schedule: 'Lundi matin',
      );

      expect(callable.capturedPayload!['schedule'], {
        'description': 'Lundi matin',
      });
    });

    test('omits schedule key when schedule is empty', () async {
      final callable = _FakeCallable(response: {'bookingId': 'booking_abc'});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await useCase(
        providerId: 'p',
        serviceId: 's',
        requestMessage: 'm',
        schedule: '',
      );

      expect(callable.capturedPayload!.containsKey('schedule'), isFalse);
    });

    test('includes addressSnapshot when address is non-empty', () async {
      final callable = _FakeCallable(response: {'bookingId': 'booking_abc'});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await useCase(
        providerId: 'p',
        serviceId: 's',
        requestMessage: 'm',
        address: '12 rue de la Paix',
      );

      expect(callable.capturedPayload!['addressSnapshot'], {
        'address': '12 rue de la Paix',
      });
    });

    test('omits addressSnapshot when address is empty', () async {
      final callable = _FakeCallable(response: {'bookingId': 'booking_abc'});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await useCase(
        providerId: 'p',
        serviceId: 's',
        requestMessage: 'm',
        address: '',
      );

      expect(callable.capturedPayload!.containsKey('addressSnapshot'), isFalse);
    });

    test('throws Exception when bookingId is absent from response', () async {
      final callable = _FakeCallable(response: {});
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await expectLater(
        useCase(providerId: 'p', serviceId: 's', requestMessage: 'm'),
        throwsA(isA<Exception>()),
      );
    });

    test('propagates FirebaseFunctionsException', () async {
      final callable = _FakeCallable(
        response: null,
        shouldThrow: FirebaseFunctionsException(
          message: 'unauthenticated',
          code: 'unauthenticated',
        ),
      );
      final functions = _FakeFunctions(callable);
      final useCase = CreateBookingUseCase(functions);

      await expectLater(
        useCase(providerId: 'p', serviceId: 's', requestMessage: 'm'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });
  });
}
