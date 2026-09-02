// Covers the two write paths of the user repository, and above all the
// difference between them, which is the whole reason setProfileImage exists.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_user_repository.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

AppUser _user({String? photoPath, String? avatarId}) => AppUser(
  id: 'u1',
  displayName: 'Awa Diop',
  email: 'awa@test.com',
  country: 'SN',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1),
  photoPath: photoPath,
  avatarId: avatarId,
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreUserRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreUserRepository(db);
  });

  Future<Map<String, Object?>> raw() async =>
      (await db.collection('users').doc('u1').get()).data()!;

  group('setProfileImage', () {
    test('choosing an avatar stores it AND removes the photo key', () async {
      await repo.upsert(_user(photoPath: 'https://example.test/a.jpg'));
      expect((await raw())['photoPath'], isNotNull);

      await repo.setProfileImage(
        userId: 'u1',
        photoPath: null,
        avatarId: 'human_afro1_t2',
      );

      final after = await raw();
      expect(after['avatarId'], 'human_afro1_t2');
      // Removed, not set to null: the key must not linger on a document that
      // is mirrored into a world-readable projection.
      expect(after.containsKey('photoPath'), isFalse);
    });

    test('importing a photo stores it AND removes the avatar key', () async {
      await repo.upsert(_user(avatarId: 'human_afro1_t2'));
      await repo.setProfileImage(
        userId: 'u1',
        photoPath: 'https://example.test/a.jpg',
        avatarId: null,
      );

      final after = await raw();
      expect(after['photoPath'], 'https://example.test/a.jpg');
      expect(after.containsKey('avatarId'), isFalse);
    });

    test('choosing neither removes both keys', () async {
      await repo.upsert(
        _user(
          photoPath: 'https://example.test/a.jpg',
          avatarId: 'animal_blob1',
        ),
      );
      await repo.setProfileImage(userId: 'u1', photoPath: null, avatarId: null);

      final after = await raw();
      expect(after.containsKey('photoPath'), isFalse);
      expect(after.containsKey('avatarId'), isFalse);
    });

    test('it touches NOTHING else on the document', () async {
      // The point of a targeted write. `upsert` sends the whole AppUser, so a
      // stale in-memory copy can clobber a field another device just changed.
      // This path sends two keys, so it cannot.
      await repo.upsert(_user(avatarId: 'human_afro1_t2'));
      await db.collection('users').doc('u1').set({
        'pushToken': 'token-from-another-device',
        'displayName': 'Renamed elsewhere',
      }, SetOptions(merge: true));

      await repo.setProfileImage(
        userId: 'u1',
        photoPath: null,
        avatarId: 'animal_blob1',
      );

      final after = await raw();
      expect(after['avatarId'], 'animal_blob1');
      expect(after['pushToken'], 'token-from-another-device');
      expect(after['displayName'], 'Renamed elsewhere');
    });

    test('it creates the document if it somehow does not exist', () async {
      await repo.setProfileImage(
        userId: 'u1',
        photoPath: null,
        avatarId: 'animal_blob1',
      );
      expect((await raw())['avatarId'], 'animal_blob1');
    });
  });

  group('upsert', () {
    test('never writes avatarId as null, so it cannot erase one', () async {
      // The complement of the test above: this is why erasing needs its own
      // path rather than an `upsert` with a null.
      await repo.setProfileImage(
        userId: 'u1',
        photoPath: null,
        avatarId: 'human_afro1_t2',
      );
      // A stale in-memory user, avatar unset.
      await repo.upsert(_user());

      expect(
        (await raw())['avatarId'],
        'human_afro1_t2',
        reason: 'a whole-document merge must not have erased the avatar',
      );
    });
  });
}
