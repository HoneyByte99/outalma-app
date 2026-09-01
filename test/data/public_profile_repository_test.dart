// FirestorePublicProfileRepository + the public_profiles converter.
//
// This is the read path every guest-reachable surface now depends on, so what
// it must survive is a document written by a Cloud Function from whatever
// `users/{uid}` happened to hold: fields absent, fields empty, no document at
// all. A throw here shows a visitor a red screen on a service card.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/repositories/firestore_public_profile_repository.dart';
import 'package:outalma_app/src/domain/models/public_profile.dart';

Future<void> _write(
  FakeFirebaseFirestore db,
  String uid,
  Map<String, Object?> data,
) {
  // Raw map, not the typed converter: the collection is server-owned and its
  // toFirestore throws on purpose, so a test that wrote through it would be
  // testing a path production does not have.
  return db.collection('public_profiles').doc(uid).set(data);
}

void main() {
  group('watchById', () {
    test('returns null when the document does not exist', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestorePublicProfileRepository(db);
      expect(await repo.watchById('nobody').first, isNull);
    });

    test('returns null for an empty uid without touching Firestore', () async {
      // A Service or Review whose providerId/reviewerId failed to deserialise
      // carries ''. `doc('')` throws in cloud_firestore, which would crash the
      // whole card instead of degrading to no name.
      final db = FakeFirebaseFirestore();
      final repo = FirestorePublicProfileRepository(db);
      expect(await repo.watchById('').first, isNull);
    });

    test('reads the four projected fields', () async {
      final db = FakeFirebaseFirestore();
      await _write(db, 'u1', {
        'displayName': 'Awa Cisse',
        'photoPath': 'https://storage.example/a.png',
        'country': 'SN',
        'phoneVerified': true,
      });
      final profile = await FirestorePublicProfileRepository(
        db,
      ).watchById('u1').first;

      expect(profile, isNotNull);
      expect(profile!.id, 'u1');
      expect(profile.displayName, 'Awa Cisse');
      expect(profile.photoPath, 'https://storage.example/a.png');
      expect(profile.country, 'SN');
      expect(profile.phoneVerified, isTrue);
    });

    test(
      'degrades to a blank name rather than throwing on an empty doc',
      () async {
        final db = FakeFirebaseFirestore();
        await _write(db, 'u1', const <String, Object?>{});
        final profile = await FirestorePublicProfileRepository(
          db,
        ).watchById('u1').first;

        expect(profile, isNotNull);
        expect(profile!.displayName, isEmpty);
        expect(profile.photoPath, isNull);
        expect(profile.phoneVerified, isFalse);
      },
    );

    test(
      'leaves country null when absent, never defaulting it to FR',
      () async {
        // AppUser defaults country to 'FR' because the app needs one. A public
        // profile must not: 8 of the 50 production documents carry no country,
        // and a default would show a flag the user never declared.
        final db = FakeFirebaseFirestore();
        await _write(db, 'u1', {'displayName': 'Awa', 'phoneVerified': false});
        final profile = await FirestorePublicProfileRepository(
          db,
        ).watchById('u1').first;

        expect(profile!.country, isNull);
      },
    );

    // NO liveness test here, and it is a gap rather than an oversight.
    // fake_cloud_firestore only notifies a `withConverter` listener for writes
    // that ALSO go through a converter, and this collection's toFirestore
    // throws by design (server-owned). Every other repository test in this
    // folder writes through its converter, which is why they can assert it.
    // A test written against the raw collection would observe one emission and
    // pass for the wrong reason. Liveness of `snapshots()` itself is a
    // cloud_firestore guarantee already pinned by user_repository_test.
  });

  test(
    'the converter refuses to serialise: the collection is server-owned',
    () {
      // Client writes are denied by the Firestore rule. A working toFirestore
      // would advertise a write path that only ever fails at the network layer,
      // and the failure would surface far from the line that caused it.
      final db = FakeFirebaseFirestore();
      expect(
        () => FirestoreCollections.publicProfiles(
          db,
        ).doc('u1').set(const PublicProfile(id: 'u1', displayName: 'Impostor')),
        throwsUnsupportedError,
      );
    },
  );
}
