// Verifies the PublicProfile model + its Firestore converter roundtrip.
//
// The projection must carry ONLY non-PII display fields: displayName,
// photoPath, country and the phoneVerified boolean. No email / phone.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/models/public_profile.dart';

void main() {
  group('PublicProfile model', () {
    test('phoneVerified defaults to false, optionals to null', () {
      const p = PublicProfile(id: 'u1', displayName: 'Awa');
      expect(p.photoPath, isNull);
      expect(p.country, isNull);
      expect(p.phoneVerified, isFalse);
    });
  });

  group('PublicProfile serialization', () {
    late FakeFirebaseFirestore fakeDb;
    setUp(() => fakeDb = FakeFirebaseFirestore());

    test('roundtrip preserves all fields', () async {
      const p = PublicProfile(
        id: 'p1',
        displayName: 'Awa Ndiaye',
        photoPath: 'avatars/p1.jpg',
        country: 'SN',
        phoneVerified: true,
      );
      final col = FirestoreCollections.publicProfiles(fakeDb);
      await col.doc(p.id).set(p);
      final result = (await col.doc(p.id).get()).data()!;

      expect(result.id, 'p1');
      expect(result.displayName, 'Awa Ndiaye');
      expect(result.photoPath, 'avatars/p1.jpg');
      expect(result.country, 'SN');
      expect(result.phoneVerified, isTrue);
    });

    test('omits photoPath / country from the map when null', () async {
      const p = PublicProfile(id: 'p2', displayName: 'Bou');
      await FirestoreCollections.publicProfiles(fakeDb).doc(p.id).set(p);

      final raw = (await fakeDb.collection('public_profiles').doc('p2').get())
          .data()!;
      expect(raw.containsKey('photoPath'), isFalse);
      expect(raw.containsKey('country'), isFalse);
      expect(raw['displayName'], 'Bou');
      expect(raw['phoneVerified'], false);
    });

    test('missing displayName falls back to empty string', () async {
      await fakeDb.collection('public_profiles').doc('nn').set({
        'phoneVerified': true,
      });
      final result = (await FirestoreCollections.publicProfiles(
        fakeDb,
      ).doc('nn').get()).data()!;
      expect(result.displayName, '');
      expect(result.phoneVerified, isTrue);
    });

    test('missing phoneVerified defaults to false', () async {
      await fakeDb.collection('public_profiles').doc('nv').set({
        'displayName': 'X',
      });
      final result = (await FirestoreCollections.publicProfiles(
        fakeDb,
      ).doc('nv').get()).data()!;
      expect(result.phoneVerified, isFalse);
    });
  });
}
