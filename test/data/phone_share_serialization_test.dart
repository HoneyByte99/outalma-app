// Verifies that PhoneShare objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// The collection lives at bookings/{bookingId}/phoneShares/{uid}.
// The document ID is the UID of the user whose phone is shared.
//
// Critical cases:
//   - All fields roundtrip
//   - bookingId reference (via subcollection path)
//   - uid (sharedByUid) preserved as document ID
//   - phone number preserved
//   - createdAt Timestamp ↔ DateTime conversion
//   - Missing fields → safe defaults, no crash

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/models/phone_share.dart';

PhoneShare _makePhoneShare({
  String uid = 'user_provider_1',
  String phone = '+33612345678',
  DateTime? createdAt,
}) {
  return PhoneShare(
    uid: uid,
    phone: phone,
    createdAt: createdAt ?? DateTime(2024, 5, 5, 9, 0).toUtc(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;
  const testBookingId = 'booking_abc';

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('PhoneShare serialization — all fields', () {
    test('roundtrip preserves all fields', () async {
      final ps = _makePhoneShare();
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      await col.doc(ps.uid).set(ps);
      final result = (await col.doc(ps.uid).get()).data()!;

      expect(result.uid, ps.uid);
      expect(result.phone, '+33612345678');
    });
  });

  group('PhoneShare serialization — bookingId reference', () {
    test('documents from different bookings are isolated', () async {
      final ps1 = _makePhoneShare(uid: 'user_1', phone: '+33611111111');
      final ps2 = _makePhoneShare(uid: 'user_2', phone: '+33622222222');

      final col1 = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: 'booking_1',
      );
      final col2 = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: 'booking_2',
      );

      await col1.doc(ps1.uid).set(ps1);
      await col2.doc(ps2.uid).set(ps2);

      final result1 = (await col1.doc(ps1.uid).get()).data()!;
      final result2 = (await col2.doc(ps2.uid).get()).data()!;

      expect(result1.phone, '+33611111111');
      expect(result2.phone, '+33622222222');

      // Cross-access should return no document
      final crossAccess = await col1.doc(ps2.uid).get();
      expect(crossAccess.data(), isNull);
    });
  });

  group('PhoneShare serialization — uid as document ID', () {
    test('uid is taken from document ID (snap.id)', () async {
      final ps = _makePhoneShare(uid: 'provider_uid_42');
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      await col.doc(ps.uid).set(ps);
      final result = (await col.doc(ps.uid).get()).data()!;
      expect(result.uid, 'provider_uid_42');
    });
  });

  group('PhoneShare serialization — phone numbers', () {
    test('French E.164 number roundtrips correctly', () async {
      final ps = _makePhoneShare(phone: '+33698765432');
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      await col.doc(ps.uid).set(ps);
      final result = (await col.doc(ps.uid).get()).data()!;
      expect(result.phone, '+33698765432');
    });

    test('Senegalese E.164 number roundtrips correctly', () async {
      final ps = _makePhoneShare(
        uid: 'user_sn',
        phone: '+221771234567',
      );
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      await col.doc(ps.uid).set(ps);
      final result = (await col.doc(ps.uid).get()).data()!;
      expect(result.phone, '+221771234567');
    });
  });

  group('PhoneShare serialization — createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 8, 1, 12, 0, 0).toUtc();
      final ps = _makePhoneShare(createdAt: t);
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      await col.doc(ps.uid).set(ps);
      final result = (await col.doc(ps.uid).get()).data()!;

      expect(
        result.createdAt.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
      );
    });

    test('createdAt is stored as Firestore Timestamp', () async {
      final ps = _makePhoneShare();
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      await col.doc(ps.uid).set(ps);

      final raw = (await fakeDb
              .collection('bookings')
              .doc(testBookingId)
              .collection('phoneShares')
              .doc(ps.uid)
              .get())
          .data()!;
      expect(raw['createdAt'], isA<Timestamp>());
    });
  });

  group('PhoneShare serialization — safe defaults for missing fields', () {
    test('missing fields do not crash and use safe defaults', () async {
      await fakeDb
          .collection('bookings')
          .doc(testBookingId)
          .collection('phoneShares')
          .doc('minimal_uid')
          .set({
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.phoneShares(
        db: fakeDb,
        bookingId: testBookingId,
      );
      final result = (await col.doc('minimal_uid').get()).data()!;

      expect(result.uid, 'minimal_uid');
      expect(result.phone, '');
    });
  });
}
