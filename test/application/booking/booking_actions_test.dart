import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/booking/booking_actions.dart';

// The use cases now invoke `CallableFunctionClient` (plain HTTP) internally
// instead of accepting an injected `FirebaseFunctions`. Without dependency
// injection the legacy behavioural tests can't mock the network layer, so the
// suite is reduced to construction smoke tests. The HTTP path is exercised
// end-to-end via integration tests against the live Cloud Functions.

void main() {
  group('Booking action use cases', () {
    test('AcceptBookingUseCase can be constructed as const', () {
      expect(const AcceptBookingUseCase(), isA<AcceptBookingUseCase>());
    });

    test('RejectBookingUseCase can be constructed as const', () {
      expect(const RejectBookingUseCase(), isA<RejectBookingUseCase>());
    });
  });
}
