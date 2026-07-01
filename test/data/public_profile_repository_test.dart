// Tests for FirestorePublicProfileRepository using FakeFirebaseFirestore.
//
// watchById: null for a missing uid, the profile for an existing uid, and a
// live update when the underlying doc changes.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_public_profile_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestorePublicProfileRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestorePublicProfileRepository(fakeDb);
  });

  Future<void> seed(String uid, Map<String, Object?> data) {
    return fakeDb.collection('public_profiles').doc(uid).set(data);
  }

  test('watchById emits null when the profile does not exist', () async {
    expect(await repo.watchById('missing').first, isNull);
  });

  test('watchById emits the profile when it exists', () async {
    await seed('p1', {
      'displayName': 'Awa',
      'photoPath': 'avatars/p1.jpg',
      'country': 'SN',
      'phoneVerified': true,
    });

    final p = await repo.watchById('p1').first;
    expect(p, isNotNull);
    expect(p!.id, 'p1');
    expect(p.displayName, 'Awa');
    expect(p.photoPath, 'avatars/p1.jpg');
    expect(p.country, 'SN');
    expect(p.phoneVerified, isTrue);
  });

  test('watchById reflects the current stored value after an update', () async {
    await seed('p1', {'displayName': 'Old', 'phoneVerified': false});
    expect((await repo.watchById('p1').first)?.displayName, 'Old');

    await seed('p1', {'displayName': 'New', 'phoneVerified': false});
    expect((await repo.watchById('p1').first)?.displayName, 'New');
  });
}
