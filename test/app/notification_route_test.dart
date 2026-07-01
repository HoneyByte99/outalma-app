// Unit tests for notificationRouteForData - the rule that maps a push
// notification's FCM data payload to an in-app deep-link route.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/notification_route.dart';

void main() {
  group('notificationRouteForData', () {
    test('routes to the chat when chatId is present', () {
      expect(
        notificationRouteForData({'type': 'new_message', 'chatId': 'c123'}),
        '/chat/c123',
      );
    });

    test('routes to the booking detail when only bookingId is present', () {
      expect(
        notificationRouteForData({
          'type': 'booking_requested',
          'bookingId': 'b9',
        }),
        '/bookings/b9',
      );
    });

    test('prefers the chat route when both ids are present', () {
      expect(
        notificationRouteForData({'chatId': 'c1', 'bookingId': 'b1'}),
        '/chat/c1',
      );
    });

    test('returns null when no recognizable target is present', () {
      expect(notificationRouteForData({'type': 'generic'}), isNull);
      expect(notificationRouteForData({}), isNull);
    });

    test('ignores empty-string ids', () {
      expect(notificationRouteForData({'chatId': '', 'bookingId': ''}), isNull);
      expect(
        notificationRouteForData({'chatId': '', 'bookingId': 'b2'}),
        '/bookings/b2',
      );
    });
  });
}
