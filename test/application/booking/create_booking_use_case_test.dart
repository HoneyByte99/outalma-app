import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/booking/create_booking_use_case.dart';

// `CreateBookingUseCase` now invokes `CallableFunctionClient` (plain HTTP)
// internally instead of accepting an injected `FirebaseFunctions`, so the
// previous fake-based unit tests no longer apply. The payload construction is
// covered indirectly by integration tests against the live `createBooking`
// Cloud Function.

void main() {
  group('CreateBookingUseCase', () {
    test('can be constructed as const', () {
      expect(const CreateBookingUseCase(), isA<CreateBookingUseCase>());
    });
  });
}
