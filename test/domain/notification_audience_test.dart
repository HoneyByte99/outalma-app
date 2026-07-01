import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
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

      test('service moderation + suspension → provider', () {
        for (final t in [
          'service_approved',
          'service_rejected',
          'provider_suspended',
        ]) {
          expect(
            notificationAudienceOf(notif(type: t)),
            NotificationAudience.provider,
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
          'review_received',
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

  group('activeModeForAudience - deep-link mode switch', () {
    test('client/provider map to their mode, both leaves mode unchanged', () {
      expect(
        activeModeForAudience(NotificationAudience.client),
        ActiveMode.client,
      );
      expect(
        activeModeForAudience(NotificationAudience.provider),
        ActiveMode.provider,
      );
      expect(activeModeForAudience(NotificationAudience.both), isNull);
    });
  });

  group('notificationAudienceFor - raw fields (push payloads)', () {
    test('explicit audience wins; type infers otherwise', () {
      expect(
        notificationAudienceFor(audience: 'provider', type: 'new_message'),
        NotificationAudience.provider,
      );
      expect(
        notificationAudienceFor(audience: null, type: 'booking_requested'),
        NotificationAudience.provider,
      );
      expect(
        notificationAudienceFor(audience: null, type: 'booking_accepted'),
        NotificationAudience.client,
      );
      expect(
        notificationAudienceFor(audience: null, type: 'new_message'),
        NotificationAudience.both,
      );
    });
  });
}
