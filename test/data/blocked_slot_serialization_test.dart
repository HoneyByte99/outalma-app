// Verifies that BlockedSlot objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// The collection lives at providers/{uid}/blocked_slots/{id}.
//
// Critical cases:
//   - All fields roundtrip
//   - date (start) as Firestore Timestamp
//   - endDate null (full-day block) / non-null (time range)
//   - isFullDay computed getter reflects endDate presence
//   - reason null / non-null
//   - Missing fields → safe defaults, no crash

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/models/blocked_slot.dart';

BlockedSlot _makeSlot({
  String id = 'slot_1',
  DateTime? date,
  DateTime? endDate,
  String? reason,
}) {
  return BlockedSlot(
    id: id,
    date: date ?? DateTime(2024, 9, 10, 8, 0).toUtc(),
    endDate: endDate,
    reason: reason,
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;
  const testUid = 'provider_uid_1';

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('BlockedSlot serialization - all fields', () {
    test('roundtrip preserves all fields with endDate and reason', () async {
      final slot = _makeSlot(
        endDate: DateTime(2024, 9, 10, 18, 0).toUtc(),
        reason: 'Congé',
      );
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;

      expect(result.id, slot.id);
      expect(
        result.date.millisecondsSinceEpoch,
        slot.date.millisecondsSinceEpoch,
      );
      expect(result.endDate, isNotNull);
      expect(
        result.endDate!.millisecondsSinceEpoch,
        slot.endDate!.millisecondsSinceEpoch,
      );
      expect(result.reason, 'Congé');
    });
  });

  group('BlockedSlot serialization - date as Timestamp', () {
    test('date is stored as Firestore Timestamp', () async {
      final slot = _makeSlot();
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);

      final raw =
          (await fakeDb
                  .collection('providers')
                  .doc(testUid)
                  .collection('blocked_slots')
                  .doc(slot.id)
                  .get())
              .data()!;
      expect(raw['date'], isA<Timestamp>());
    });

    test('date roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 12, 25, 0, 0, 0).toUtc();
      final slot = _makeSlot(date: t);
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;

      expect(result.date.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
    });
  });

  group('BlockedSlot serialization - endDate null / non-null', () {
    test('null endDate (full-day block) roundtrips as null', () async {
      final slot = _makeSlot(endDate: null);
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;
      expect(result.endDate, isNull);
    });

    test('non-null endDate (time range) roundtrips correctly', () async {
      final start = DateTime(2024, 9, 15, 9, 0).toUtc();
      final end = DateTime(2024, 9, 15, 17, 0).toUtc();
      final slot = _makeSlot(id: 'slot_range', date: start, endDate: end);
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;

      expect(result.endDate, isNotNull);
      expect(
        result.endDate!.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      );
    });

    test('endDate stored as Firestore Timestamp when non-null', () async {
      final slot = _makeSlot(
        id: 'slot_ts',
        endDate: DateTime(2024, 9, 10, 18, 0).toUtc(),
      );
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);

      final raw =
          (await fakeDb
                  .collection('providers')
                  .doc(testUid)
                  .collection('blocked_slots')
                  .doc(slot.id)
                  .get())
              .data()!;
      expect(raw['endDate'], isA<Timestamp>());
    });
  });

  group('BlockedSlot serialization - isFullDay computed getter', () {
    test('isFullDay is true when endDate is null', () async {
      final slot = _makeSlot(endDate: null);
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;
      expect(result.isFullDay, isTrue);
    });

    test('isFullDay is false when endDate is set', () async {
      final slot = _makeSlot(
        id: 'slot_not_fullday',
        endDate: DateTime(2024, 9, 10, 18, 0).toUtc(),
      );
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;
      expect(result.isFullDay, isFalse);
    });
  });

  group('BlockedSlot serialization - reason null / non-null', () {
    test('null reason roundtrips as null', () async {
      final slot = _makeSlot(reason: null);
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;
      expect(result.reason, isNull);
    });

    test('non-null reason roundtrips correctly', () async {
      final slot = _makeSlot(id: 'slot_reason', reason: 'RDV perso');
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      await col.doc(slot.id).set(slot);
      final result = (await col.doc(slot.id).get()).data()!;
      expect(result.reason, 'RDV perso');
    });
  });

  group('BlockedSlot serialization - safe defaults for missing fields', () {
    test('missing fields do not crash and use safe defaults', () async {
      await fakeDb
          .collection('providers')
          .doc(testUid)
          .collection('blocked_slots')
          .doc('minimal')
          .set({'date': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc())});
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      final result = (await col.doc('minimal').get()).data()!;

      expect(result.endDate, isNull);
      expect(result.reason, isNull);
      expect(result.isFullDay, isTrue);
    });

    test('completely missing date falls back to epoch', () async {
      await fakeDb
          .collection('providers')
          .doc(testUid)
          .collection('blocked_slots')
          .doc('no_date')
          .set(<String, dynamic>{});
      final col = FirestoreCollections.blockedSlots(fakeDb, testUid);
      final result = (await col.doc('no_date').get()).data()!;

      expect(result.date, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });
  });
}
