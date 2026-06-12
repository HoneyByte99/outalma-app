import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/chat/chat_providers.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

class _AuthedNotifier extends AuthNotifier {
  _AuthedNotifier(this._user);
  final AppUser _user;
  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

AppUser _me() => AppUser(
  id: 'me',
  displayName: 'Me',
  email: 'me@test.dev',
  country: 'FR',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

ProviderContainer _container(FakeFirebaseFirestore db) => ProviderContainer(
  overrides: [
    authNotifierProvider.overrideWith(() => _AuthedNotifier(_me())),
    firestoreProvider.overrideWithValue(db),
  ],
);

// Seed via the typed converter so getById() reads it back cleanly.
Future<void> _seedUser(FakeFirebaseFirestore db, String id, String name) =>
    FirestoreCollections.users(db)
        .doc(id)
        .set(
          AppUser(
            id: id,
            displayName: name,
            email: '$id@test.dev',
            country: 'FR',
            activeMode: ActiveMode.client,
            createdAt: DateTime(2024, 1, 1).toUtc(),
          ),
        );

Future<List<AppUser>> _waitForBlocked(ProviderContainer c) async {
  for (var i = 0; i < 25; i++) {
    final v = await c.read(blockedUsersProvider.future);
    if (v.isNotEmpty) return v;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return c.read(blockedUsersProvider.future);
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  group('UserBlockService', () {
    test('block writes the blocked doc, unblock removes it', () async {
      final container = _container(db);
      addTearDown(container.dispose);
      // Resolve auth first so the service captures the real uid (not null).
      await container.read(authNotifierProvider.future);
      final svc = container.read(userBlockServiceProvider);

      await svc.block('bob');
      final after = await db
          .collection('users')
          .doc('me')
          .collection('blockedUsers')
          .doc('bob')
          .get();
      expect(after.exists, isTrue);

      await svc.unblock('bob');
      final gone = await db
          .collection('users')
          .doc('me')
          .collection('blockedUsers')
          .doc('bob')
          .get();
      expect(gone.exists, isFalse);
    });
  });

  group('blockedUsersProvider', () {
    test('resolves blocked ids to user profiles', () async {
      await _seedUser(db, 'bob', 'Bob');
      await db
          .collection('users')
          .doc('me')
          .collection('blockedUsers')
          .doc('bob')
          .set({'createdAt': Timestamp.now()});

      final container = _container(db);
      addTearDown(container.dispose);
      // Drive the async auth build so the stable uid resolves to 'me' and
      // blockedUserIdsProvider subscribes to the real subcollection.
      await container.read(authNotifierProvider.future);
      container.listen(blockedUserIdsProvider, (_, __) {});
      container.listen(blockedUsersProvider, (_, __) {});

      final ids = await container.read(blockedUserIdsProvider.future);
      expect(ids, contains('bob'), reason: 'ids should include bob');
      final bob = await container.read(userRepositoryProvider).getById('bob');
      expect(bob, isNotNull, reason: 'getById bob should resolve');

      final users = await _waitForBlocked(container);
      expect(users, hasLength(1));
      expect(users.first.id, 'bob');
      expect(users.first.displayName, 'Bob');
    });

    test('is empty when nothing is blocked', () async {
      final container = _container(db);
      addTearDown(container.dispose);
      container.listen(blockedUsersProvider, (_, __) {});
      // Wait for the ids stream to emit its (empty) first value.
      await container.read(blockedUserIdsProvider.future);
      final users = await container.read(blockedUsersProvider.future);
      expect(users, isEmpty);
    });
  });
}
