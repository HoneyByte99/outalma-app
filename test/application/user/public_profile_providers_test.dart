// Riverpod wiring for the guest-safe display projection.
//
// What matters here is that the provider family resolves WITHOUT an
// authenticated user: it is the only display source a visitor with no account
// has, so a hidden dependency on auth would reintroduce the exact bug this
// projection exists to fix.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/data/repositories/firestore_public_profile_repository.dart';
import 'package:outalma_app/src/domain/models/public_profile.dart';
import 'package:outalma_app/src/domain/repositories/public_profile_repository.dart';

class _FakeRepo implements PublicProfileRepository {
  _FakeRepo(this._profiles);
  final Map<String, PublicProfile> _profiles;
  final asked = <String>[];

  @override
  Stream<PublicProfile?> watchById(String uid) {
    asked.add(uid);
    return Stream.value(_profiles[uid]);
  }
}

void main() {
  test('publicProfileRepositoryProvider builds on the injected Firestore', () {
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(FakeFirebaseFirestore())],
    );
    addTearDown(container.dispose);

    expect(
      container.read(publicProfileRepositoryProvider),
      isA<FirestorePublicProfileRepository>(),
    );
  });

  test(
    'resolves a profile with NO authenticated user in the container',
    () async {
      // No authNotifierProvider override, no signed-in user: the whole point.
      final repo = _FakeRepo({
        'prov_1': const PublicProfile(
          id: 'prov_1',
          displayName: 'Awa Cisse',
          photoPath: 'https://storage.example/a.png',
          country: 'SN',
          phoneVerified: true,
        ),
      });
      final container = ProviderContainer(
        overrides: [publicProfileRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final profile = await container.read(
        publicProfileByIdProvider('prov_1').future,
      );

      expect(profile?.displayName, 'Awa Cisse');
      expect(profile?.phoneVerified, isTrue);
      expect(repo.asked, ['prov_1']);
    },
  );

  test('an unknown uid resolves to null rather than erroring', () async {
    // A review whose author deleted their account still lists. The tile must
    // render with no name, not throw inside a sliver a visitor is scrolling.
    final container = ProviderContainer(
      overrides: [
        publicProfileRepositoryProvider.overrideWithValue(_FakeRepo(const {})),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(publicProfileByIdProvider('ghost').future),
      isNull,
    );
  });

  test('reads through the real repository against a fake Firestore', () async {
    // End to end over the actual converter, so a change to the field names in
    // firestore_collections.dart breaks here rather than in production.
    final db = FakeFirebaseFirestore();
    await db.collection('public_profiles').doc('u1').set({
      'displayName': 'Doudou SARR',
      'phoneVerified': false,
    });
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final profile = await container.read(
      publicProfileByIdProvider('u1').future,
    );

    expect(profile?.displayName, 'Doudou SARR');
    expect(profile?.country, isNull);
  });
}
