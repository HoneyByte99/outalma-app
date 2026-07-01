// Covers publicProfileRepositoryProvider + publicProfileByIdProvider wiring.
//
// Overrides firestoreProvider with a fake so the family provider resolves a
// real projection stream without touching a live backend.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/domain/repositories/public_profile_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late ProviderContainer container;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(fakeDb)],
    );
  });
  tearDown(() => container.dispose());

  test('publicProfileRepositoryProvider builds a repository', () {
    expect(
      container.read(publicProfileRepositoryProvider),
      isA<PublicProfileRepository>(),
    );
  });

  test('publicProfileByIdProvider streams the projection', () async {
    await fakeDb.collection('public_profiles').doc('p1').set({
      'displayName': 'Awa',
      'country': 'SN',
      'phoneVerified': true,
    });

    final profile = await container.read(
      publicProfileByIdProvider('p1').future,
    );
    expect(profile, isNotNull);
    expect(profile!.displayName, 'Awa');
    expect(profile.country, 'SN');
    expect(profile.phoneVerified, isTrue);
  });

  test('publicProfileByIdProvider emits null for a missing profile', () async {
    final profile = await container.read(
      publicProfileByIdProvider('ghost').future,
    );
    expect(profile, isNull);
  });
}
