import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/booking/booking_actions.dart';

// See booking_actions_test.dart for rationale: lifecycle use cases now use
// `CallableFunctionClient` internally and cannot be mocked at unit-test level.

void main() {
  group('Booking lifecycle use cases', () {
    test('MarkInProgressUseCase can be constructed as const', () {
      expect(const MarkInProgressUseCase(), isA<MarkInProgressUseCase>());
    });

    test('ConfirmDoneUseCase can be constructed as const', () {
      expect(const ConfirmDoneUseCase(), isA<ConfirmDoneUseCase>());
    });

    test('CancelBookingUseCase can be constructed as const', () {
      expect(const CancelBookingUseCase(), isA<CancelBookingUseCase>());
    });
  });
}
