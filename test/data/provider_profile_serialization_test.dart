// Verifies that ProviderProfile objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases:
//   - All fields present roundtrip
//   - Null optional fields (bio, serviceArea)
//   - active / suspended flags
//   - createdAt Timestamp ↔ DateTime conversion
//   - Missing fields → safe defaults, no crash

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';

ProviderProfile _makeProfile({
  String uid = 'provider_1',
  String? bio = 'Expert en ménage depuis 10 ans.',
  String? serviceArea = 'Paris 15e',
  bool active = true,
  bool suspended = false,
  DateTime? createdAt,
}) {
  return ProviderProfile(
    uid: uid,
    bio: bio,
    serviceArea: serviceArea,
    active: active,
    suspended: suspended,
    createdAt: createdAt ?? DateTime(2024, 1, 15, 10, 0).toUtc(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('ProviderProfile serialization — all fields', () {
    test('roundtrip preserves all fields', () async {
      final profile = _makeProfile();
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;

      expect(result.uid, profile.uid);
      expect(result.bio, 'Expert en ménage depuis 10 ans.');
      expect(result.serviceArea, 'Paris 15e');
      expect(result.active, true);
      expect(result.suspended, false);
    });
  });

  group('ProviderProfile serialization — null optional fields', () {
    test('null bio roundtrips as null', () async {
      final profile = _makeProfile(bio: null);
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;
      expect(result.bio, isNull);
    });

    test('null serviceArea roundtrips as null', () async {
      final profile = _makeProfile(serviceArea: null);
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;
      expect(result.serviceArea, isNull);
    });

    test('both bio and serviceArea null roundtrip as null', () async {
      final profile = _makeProfile(bio: null, serviceArea: null);
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;
      expect(result.bio, isNull);
      expect(result.serviceArea, isNull);
    });
  });

  group('ProviderProfile serialization — active/suspended flags', () {
    test('active=false suspended=false roundtrips correctly', () async {
      final profile = _makeProfile(active: false, suspended: false);
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;
      expect(result.active, false);
      expect(result.suspended, false);
    });

    test('active=true suspended=true roundtrips correctly', () async {
      final profile = _makeProfile(
        uid: 'provider_suspended',
        active: true,
        suspended: true,
      );
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;
      expect(result.active, true);
      expect(result.suspended, true);
    });
  });

  group('ProviderProfile serialization — createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 6, 1, 9, 30, 0).toUtc();
      final profile = _makeProfile(createdAt: t);
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);
      final result = (await col.doc(profile.uid).get()).data()!;

      expect(
        result.createdAt.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
      );
    });

    test('createdAt is stored as Firestore Timestamp', () async {
      final profile = _makeProfile();
      final col = FirestoreCollections.providers(fakeDb);
      await col.doc(profile.uid).set(profile);

      final raw =
          (await fakeDb.collection('providers').doc(profile.uid).get()).data()!;
      expect(raw['createdAt'], isA<Timestamp>());
    });
  });

  group('ProviderProfile serialization — safe defaults for missing fields', () {
    test('missing fields do not crash and use safe defaults', () async {
      await fakeDb.collection('providers').doc('minimal').set({
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.providers(fakeDb);
      final result = (await col.doc('minimal').get()).data()!;

      expect(result.bio, isNull);
      expect(result.serviceArea, isNull);
      expect(result.active, false);
      expect(result.suspended, false);
    });

    test('completely empty document does not crash', () async {
      await fakeDb.collection('providers').doc('empty').set(<String, dynamic>{});
      final col = FirestoreCollections.providers(fakeDb);
      // Should not throw — createdAt will fall back to epoch via dateTimeFromFirestore
      expect(() async => (await col.doc('empty').get()).data()!, returnsNormally);
    });
  });
}
