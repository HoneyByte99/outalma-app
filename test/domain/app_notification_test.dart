import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/models/app_notification.dart';

AppNotification _unread() => AppNotification(
      id: 'n1',
      type: 'booking_accepted',
      title: 'Réservation acceptée',
      body: 'Votre réservation a été acceptée.',
      read: false,
      createdAt: DateTime(2024, 3, 15),
    );

void main() {
  group('AppNotification.isRead behavior', () {
    test('read is false by default in fixture', () {
      expect(_unread().read, isFalse);
    });

    test('copyWith(read: true) marks as read', () {
      final n = _unread().copyWith(read: true);
      expect(n.read, isTrue);
    });

    test('copyWith without argument preserves read=false', () {
      final n = _unread().copyWith();
      expect(n.read, isFalse);
    });

    test('copyWith preserves all other fields', () {
      final n = _unread().copyWith(read: true);
      expect(n.id, 'n1');
      expect(n.type, 'booking_accepted');
      expect(n.title, 'Réservation acceptée');
      expect(n.body, 'Votre réservation a été acceptée.');
      expect(n.bookingId, isNull);
      expect(n.chatId, isNull);
    });
  });

  group('AppNotification optional fields', () {
    test('bookingId and chatId default to null', () {
      final n = _unread();
      expect(n.bookingId, isNull);
      expect(n.chatId, isNull);
    });

    test('bookingId is retained when set', () {
      final n = AppNotification(
        id: 'n2',
        type: 'booking_in_progress',
        title: 'En cours',
        body: 'La prestation a démarré.',
        read: false,
        createdAt: DateTime(2024, 3, 16),
        bookingId: 'b42',
      );
      expect(n.bookingId, 'b42');
      expect(n.chatId, isNull);
    });

    test('new_message type carries chatId', () {
      final n = AppNotification(
        id: 'n3',
        type: 'new_message',
        title: 'Nouveau message',
        body: 'Vous avez reçu un message.',
        read: false,
        createdAt: DateTime(2024, 3, 17),
        chatId: 'chat99',
      );
      expect(n.chatId, 'chat99');
      expect(n.bookingId, isNull);
    });
  });

  group('AppNotification known type strings', () {
    const knownTypes = [
      'booking_accepted',
      'booking_rejected',
      'booking_in_progress',
      'booking_done',
      'new_message',
    ];

    test('all canonical types are non-empty strings', () {
      for (final t in knownTypes) {
        expect(t, isNotEmpty);
      }
    });
  });
}
