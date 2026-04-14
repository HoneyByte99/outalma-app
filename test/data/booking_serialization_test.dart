// Verifies that Booking objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases per CLAUDE.md:
//   - "in_progress" string ↔ BookingStatus.inProgress (underscore/camelCase mismatch)
//   - chatId null before acceptance, populated after
//   - All timestamp fields (acceptedAt, startedAt, doneAt, …) roundtrip
//   - Missing Firestore fields use safe defaults (no crash)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/models/booking.dart';

Booking _makeBooking({
  String id = 'booking_1',
  BookingStatus status = BookingStatus.requested,
  String? chatId,
  DateTime? scheduledAt,
  DateTime? acceptedAt,
  DateTime? rejectedAt,
  DateTime? cancelledAt,
  DateTime? startedAt,
  DateTime? doneAt,
}) {
  return Booking(
    id: id,
    customerId: 'customer_1',
    providerId: 'provider_1',
    serviceId: 'service_1',
    status: status,
    requestMessage: 'Bonjour, j\'ai besoin d\'aide',
    createdAt: DateTime(2024, 1, 15, 10, 0).toUtc(),
    scheduledAt: scheduledAt,
    chatId: chatId,
    acceptedAt: acceptedAt,
    rejectedAt: rejectedAt,
    cancelledAt: cancelledAt,
    startedAt: startedAt,
    doneAt: doneAt,
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Booking serialization — required fields', () {
    test('preserves all required fields through roundtrip', () async {
      final booking = _makeBooking();
      final col = FirestoreCollections.bookings(fakeDb);
      await col.doc(booking.id).set(booking);
      final result = (await col.doc(booking.id).get()).data()!;

      expect(result.id, booking.id);
      expect(result.customerId, 'customer_1');
      expect(result.providerId, 'provider_1');
      expect(result.serviceId, 'service_1');
      expect(result.requestMessage, 'Bonjour, j\'ai besoin d\'aide');
      expect(result.status, BookingStatus.requested);
    });

    test('all BookingStatus values roundtrip correctly', () async {
      final ts = Timestamp.fromDate(DateTime(2024, 1, 1).toUtc());
      for (final status in BookingStatus.values) {
        final docId = 'status_${status.name}';
        // Write raw (as Cloud Functions would) to test the deserialization path
        await fakeDb.collection('bookings').doc(docId).set({
          'customerId': 'c1',
          'providerId': 'p1',
          'serviceId': 's1',
          'requestMessage': 'test',
          'status': status.value,
          'createdAt': ts,
        });
        final col = FirestoreCollections.bookings(fakeDb);
        final result = (await col.doc(docId).get()).data()!;
        expect(
          result.status,
          status,
          reason: '"${status.value}" must deserialize to ${status.name}',
        );
      }
    });
  });

  group('Booking serialization — inProgress / in_progress alignment', () {
    test('inProgress is stored as "in_progress" string in Firestore', () async {
      final booking = _makeBooking(status: BookingStatus.inProgress);
      await FirestoreCollections.bookings(fakeDb).doc(booking.id).set(booking);

      final raw = (await fakeDb.collection('bookings').doc(booking.id).get())
          .data()!;
      expect(
        raw['status'],
        'in_progress',
        reason: 'Cloud Functions expects snake_case "in_progress"',
      );
    });

    test(
      'raw "in_progress" from Cloud Functions deserializes to inProgress',
      () async {
        await fakeDb.collection('bookings').doc('cf_booking').set({
          'customerId': 'c1',
          'providerId': 'p1',
          'serviceId': 's1',
          'requestMessage': 'test',
          'status': 'in_progress', // as written by Cloud Functions
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 15).toUtc()),
        });

        final col = FirestoreCollections.bookings(fakeDb);
        final result = (await col.doc('cf_booking').get()).data()!;
        expect(result.status, BookingStatus.inProgress);
      },
    );
  });

  group('Booking serialization — chatId lifecycle', () {
    test('chatId is null before acceptance', () async {
      final booking = _makeBooking(
        status: BookingStatus.requested,
        chatId: null,
      );
      final col = FirestoreCollections.bookings(fakeDb);
      await col.doc(booking.id).set(booking);
      final result = (await col.doc(booking.id).get()).data()!;
      expect(result.chatId, isNull);
    });

    test('chatId is preserved after acceptance', () async {
      final booking = _makeBooking(
        status: BookingStatus.accepted,
        chatId: 'chat_abc123',
        acceptedAt: DateTime(2024, 1, 16).toUtc(),
      );
      final col = FirestoreCollections.bookings(fakeDb);
      await col.doc(booking.id).set(booking);
      final result = (await col.doc(booking.id).get()).data()!;
      expect(result.chatId, 'chat_abc123');
    });
  });

  group('Booking serialization — timestamp fields', () {
    test('all timestamp fields roundtrip with millisecond precision', () async {
      final t = DateTime(2024, 3, 10, 14, 30, 0).toUtc();
      final booking = _makeBooking(
        status: BookingStatus.done,
        scheduledAt: t,
        acceptedAt: t,
        startedAt: t,
        doneAt: t,
      );
      final col = FirestoreCollections.bookings(fakeDb);
      await col.doc(booking.id).set(booking);
      final result = (await col.doc(booking.id).get()).data()!;

      expect(
        result.scheduledAt?.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
        reason: 'scheduledAt',
      );
      expect(
        result.acceptedAt?.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
        reason: 'acceptedAt',
      );
      expect(
        result.startedAt?.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
        reason: 'startedAt',
      );
      expect(
        result.doneAt?.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
        reason: 'doneAt',
      );
    });

    test('optional timestamp fields are null when not set', () async {
      final booking = _makeBooking(); // no optional timestamps
      final col = FirestoreCollections.bookings(fakeDb);
      await col.doc(booking.id).set(booking);
      final result = (await col.doc(booking.id).get()).data()!;

      expect(result.scheduledAt, isNull);
      expect(result.acceptedAt, isNull);
      expect(result.rejectedAt, isNull);
      expect(result.cancelledAt, isNull);
      expect(result.startedAt, isNull);
      expect(result.doneAt, isNull);
    });
  });

  group(
    'Booking serialization — safe defaults for incomplete Firestore docs',
    () {
      test('missing fields do not crash and use safe defaults', () async {
        // Minimal doc as might be written by a buggy client or old schema version
        await fakeDb.collection('bookings').doc('minimal').set({
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
        });
        final col = FirestoreCollections.bookings(fakeDb);
        final result = (await col.doc('minimal').get()).data()!;

        expect(result.customerId, '');
        expect(result.providerId, '');
        expect(result.serviceId, '');
        expect(result.requestMessage, '');
        expect(result.status, BookingStatus.requested); // default fallback
        expect(result.chatId, isNull);
        expect(result.scheduledAt, isNull);
      });

      test(
        'unknown status string falls back to requested (not a crash)',
        () async {
          await fakeDb.collection('bookings').doc('bad_status').set({
            'status': 'flying', // unknown value
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
          });
          final col = FirestoreCollections.bookings(fakeDb);
          final result = (await col.doc('bad_status').get()).data()!;
          expect(result.status, BookingStatus.requested);
        },
      );
    },
  );
}
