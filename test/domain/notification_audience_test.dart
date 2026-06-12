import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/models/app_notification.dart';

AppNotification notif({String type = 'new_message', String? audience}) =>
    AppNotification(
      id: 'n',
      type: type,
      title: 't',
      body: 'b',
      read: false,
      createdAt: DateTime(2026, 1, 1),
      audience: audience,
    );

void main() {
  group('notificationAudienceOf', () {
    test('uses the explicit server audience when present', () {
      expect(
        notificationAudienceOf(notif(type: 'new_message', audience: 'client')),
        NotificationAudience.client,
      );
      expect(
        notificationAudienceOf(
          notif(type: 'booking_done', audience: 'provider'),
        ),
        NotificationAudience.provider,
      );
    });

    test('explicit audience overrides what the type would infer', () {
      // booking_requested would infer provider, but the server said client.
      expect(
        notificationAudienceOf(
          notif(type: 'booking_requested', audience: 'client'),
        ),
        NotificationAudience.client,
      );
    });

    group('legacy fallback (no audience field)', () {
      test('booking_requested → provider', () {
        expect(
          notificationAudienceOf(notif(type: 'booking_requested')),
          NotificationAudience.provider,
        );
      });

      test('accepted/rejected/in_progress → client', () {
        for (final t in [
          'booking_accepted',
          'booking_rejected',
          'booking_in_progress',
        ]) {
          expect(
            notificationAudienceOf(notif(type: t)),
            NotificationAudience.client,
            reason: t,
          );
        }
      });

      test('ambiguous types → both (never hidden)', () {
        for (final t in [
          'booking_done',
          'booking_cancelled',
          'new_message',
          'booking_reminder',
          'something_unknown',
        ]) {
          expect(
            notificationAudienceOf(notif(type: t)),
            NotificationAudience.both,
            reason: t,
          );
        }
      });
    });
  });
}
