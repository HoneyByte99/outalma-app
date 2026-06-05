// Tests for FirestorePhoneShareRepository using FakeFirebaseFirestore.
//
// Covered:
//   - watchForBooking(bookingId): returns empty when no phone shares exist,
//     returns the list of phone shares for a booking, streams live updates
//   - share(bookingId, uid, phone): writes document keyed by uid, persists
//     correct phone, does not duplicate on second call (merge semantics)

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_phone_share_repository.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestorePhoneShareRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestorePhoneShareRepository(fakeDb);
  });

  // -------------------------------------------------------------------------
  // watchForBooking
  // -------------------------------------------------------------------------

  group('watchForBooking', () {
    test('returns empty list when no phone shares exist', () async {
      final list = await repo.watchForBooking('booking_1').first;
      expect(list, isEmpty);
    });

    test('returns phone shares for the correct booking', () async {
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_A',
        phone: '+33600000001',
      );

      final list = await repo.watchForBooking('booking_1').first;
      expect(list.length, 1);
      expect(list.first.uid, 'user_A');
      expect(list.first.phone, '+33600000001');
    });

    test('does not return phone shares for a different booking', () async {
      await repo.share(
        bookingId: 'booking_OTHER',
        uid: 'user_A',
        phone: '+33600000001',
      );

      final list = await repo.watchForBooking('booking_1').first;
      expect(list, isEmpty);
    });

    test('returns phone shares for both participants', () async {
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_A',
        phone: '+33600000001',
      );
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_B',
        phone: '+22170000002',
      );

      final list = await repo.watchForBooking('booking_1').first;
      expect(list.length, 2);
      expect(list.map((ps) => ps.uid), containsAll(['user_A', 'user_B']));
    });

    test('streams live updates when a share is added', () async {
      final stream = repo.watchForBooking('booking_1');

      final events = <int>[];
      final subscription = stream.listen((list) => events.add(list.length));
      addTearDown(subscription.cancel);

      // Initial empty
      await Future<void>.delayed(Duration.zero);

      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_A',
        phone: '+33600000001',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last, 1);
    });
  });

  // -------------------------------------------------------------------------
  // share
  // -------------------------------------------------------------------------

  group('share', () {
    test('completes without throwing', () async {
      await expectLater(
        repo.share(
          bookingId: 'booking_1',
          uid: 'user_A',
          phone: '+33600000001',
        ),
        completes,
      );
    });

    test('writes document keyed by uid under booking phoneShares', () async {
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_A',
        phone: '+33600000001',
      );

      final snap = await fakeDb
          .collection('bookings')
          .doc('booking_1')
          .collection('phoneShares')
          .doc('user_A')
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()?['phone'], '+33600000001');
    });

    test('persists the phone number correctly', () async {
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_B',
        phone: '+22170000099',
      );

      final snap = await fakeDb
          .collection('bookings')
          .doc('booking_1')
          .collection('phoneShares')
          .doc('user_B')
          .get();

      expect(snap.data()?['phone'], '+22170000099');
    });

    test(
      'uses merge semantics — second call does not remove createdAt',
      () async {
        await repo.share(
          bookingId: 'booking_1',
          uid: 'user_A',
          phone: '+33600000001',
        );

        // Second call with same uid (idempotent)
        await repo.share(
          bookingId: 'booking_1',
          uid: 'user_A',
          phone: '+33600000001',
        );

        final snap = await fakeDb
            .collection('bookings')
            .doc('booking_1')
            .collection('phoneShares')
            .doc('user_A')
            .get();

        expect(snap.exists, isTrue);
        expect(snap.data()?.containsKey('createdAt'), isTrue);
      },
    );

    test('each uid gets its own document', () async {
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_A',
        phone: '+33600000001',
      );
      await repo.share(
        bookingId: 'booking_1',
        uid: 'user_B',
        phone: '+22170000002',
      );

      final snap = await fakeDb
          .collection('bookings')
          .doc('booking_1')
          .collection('phoneShares')
          .get();

      expect(snap.docs.length, 2);
    });
  });
}
