import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/models/booking.dart';

final _epoch = DateTime.utc(1970);

Booking _baseBooking() {
  return Booking(
    id: 'b1',
    customerId: 'customer1',
    providerId: 'provider1',
    serviceId: 'service1',
    status: BookingStatus.requested,
    requestMessage: 'Please help',
    createdAt: _epoch,
  );
}

void main() {
  group('Booking.copyWith', () {
    test('preserves unchanged fields', () {
      final original = _baseBooking();
      final copy = original.copyWith(requestMessage: 'Updated message');

      expect(copy.id, original.id);
      expect(copy.customerId, original.customerId);
      expect(copy.providerId, original.providerId);
      expect(copy.serviceId, original.serviceId);
      expect(copy.status, original.status);
      expect(copy.createdAt, original.createdAt);
      expect(copy.requestMessage, 'Updated message');
    });

    test('updates status', () {
      final original = _baseBooking();
      final accepted = original.copyWith(status: BookingStatus.accepted);
      expect(accepted.status, BookingStatus.accepted);
    });

    test('updates chatId', () {
      final original = _baseBooking();
      final withChat = original.copyWith(chatId: 'chat_b1');
      expect(withChat.chatId, 'chat_b1');
    });
  });

  group('Booking nullable fields', () {
    test('all nullable fields default to null', () {
      final booking = _baseBooking();
      expect(booking.schedule, isNull);
      expect(booking.addressSnapshot, isNull);
      expect(booking.chatId, isNull);
      expect(booking.acceptedAt, isNull);
      expect(booking.rejectedAt, isNull);
      expect(booking.cancelledAt, isNull);
      expect(booking.startedAt, isNull);
      expect(booking.doneAt, isNull);
    });

    test('can construct booking with all nullable fields populated', () {
      final now = DateTime.utc(2024, 1, 1);
      final booking = Booking(
        id: 'b2',
        customerId: 'c',
        providerId: 'p',
        serviceId: 's',
        status: BookingStatus.done,
        requestMessage: 'msg',
        schedule: const {'start': '2024-01-01T10:00:00Z'},
        addressSnapshot: const {'street': 'Rue de Rivoli'},
        chatId: 'chat_b2',
        createdAt: now,
        acceptedAt: now,
        rejectedAt: null,
        cancelledAt: null,
        startedAt: now,
        doneAt: now,
      );

      expect(booking.chatId, 'chat_b2');
      expect(booking.acceptedAt, now);
      expect(booking.doneAt, now);
      expect(booking.rejectedAt, isNull);
    });
  });
}
