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
import 'package:outalma_app/src/domain/models/chat.dart';

class _AuthedNotifier extends AuthNotifier {
  _AuthedNotifier(this._user);
  final AppUser _user;
  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

const me = 'me';

AppUser _me(ActiveMode mode) => AppUser(
  id: me,
  displayName: 'Me',
  email: 'me@test.dev',
  country: 'FR',
  activeMode: mode,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

ProviderContainer _container(
  FakeFirebaseFirestore db, {
  ActiveMode mode = ActiveMode.client,
}) => ProviderContainer(
  overrides: [
    authNotifierProvider.overrideWith(() => _AuthedNotifier(_me(mode))),
    firestoreProvider.overrideWithValue(db),
  ],
);

Future<void> _seedChat(
  FakeFirebaseFirestore db,
  String id, {
  required String customerId,
  required String providerId,
}) => FirestoreCollections.chats(db)
    .doc(id)
    .set(
      Chat(
        id: id,
        bookingId: 'booking_$id',
        participantIds: [customerId, providerId],
        createdAt: DateTime(2024, 1, 1).toUtc(),
        customerId: customerId,
        providerId: providerId,
      ),
    );

Future<List<Chat>> _waitForChats(ProviderContainer c) async {
  for (var i = 0; i < 25; i++) {
    final v = c.read(chatsForModeProvider).valueOrNull;
    if (v != null) return v;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return c.read(chatsForModeProvider).valueOrNull ?? const [];
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test(
    'userChatsProvider returns the chats the user participates in',
    () async {
      await _seedChat(db, 'c1', customerId: me, providerId: 'bob');
      final container = _container(db);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      final chats = await container.read(userChatsProvider.future);
      expect(chats.map((c) => c.id), contains('c1'));
    },
  );

  test('client mode shows only chats where I am the customer', () async {
    await _seedChat(db, 'asClient', customerId: me, providerId: 'bob');
    await _seedChat(db, 'asProvider', customerId: 'alice', providerId: me);
    final container = _container(db, mode: ActiveMode.client);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    container.listen(chatsForModeProvider, (_, __) {});

    final chats = await _waitForChats(container);
    final ids = chats.map((c) => c.id).toSet();
    expect(ids, contains('asClient'));
    expect(ids, isNot(contains('asProvider')));
  });

  test('provider mode shows only chats where I am the provider', () async {
    await _seedChat(db, 'asClient', customerId: me, providerId: 'bob');
    await _seedChat(db, 'asProvider', customerId: 'alice', providerId: me);
    final container = _container(db, mode: ActiveMode.provider);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    container.listen(chatsForModeProvider, (_, __) {});

    final chats = await _waitForChats(container);
    final ids = chats.map((c) => c.id).toSet();
    expect(ids, contains('asProvider'));
    expect(ids, isNot(contains('asClient')));
  });

  test('a chat with a blocked participant is hidden from the list', () async {
    await _seedChat(db, 'withBob', customerId: me, providerId: 'bob');
    // Block bob.
    await db
        .collection('users')
        .doc(me)
        .collection('blockedUsers')
        .doc('bob')
        .set({'createdAt': Timestamp.now()});

    final container = _container(db, mode: ActiveMode.client);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    container.listen(chatsForModeProvider, (_, __) {});
    container.listen(blockedUserIdsProvider, (_, __) {});

    // Let the blocked set load, then the filtered list settle.
    await container.read(blockedUserIdsProvider.future);
    final chats = await _waitForChats(container);
    expect(chats.map((c) => c.id), isNot(contains('withBob')));
  });

  test('totalUnreadMessagesCountProvider is a stable placeholder (0)', () {
    final container = _container(db);
    addTearDown(container.dispose);
    expect(container.read(totalUnreadMessagesCountProvider), 0);
  });

  test('chatDetailProvider streams the chat document', () async {
    await _seedChat(db, 'c1', customerId: me, providerId: 'bob');
    final container = _container(db);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    final chat = await container.read(chatDetailProvider('c1').future);
    expect(chat?.id, 'c1');
  });

  test('chatMessagesProvider streams (empty) messages for a chat', () async {
    final container = _container(db);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    final msgs = await container.read(chatMessagesProvider('c1').future);
    expect(msgs, isEmpty);
  });

  test('otherTypingProvider yields null when nobody is typing', () async {
    final container = _container(db);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    final typing = await container.read(otherTypingProvider('c1').future);
    expect(typing, isNull);
  });

  test('blockedUsersProvider sorts resolved profiles by name', () async {
    Future<void> seedUser(String id, String name) =>
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
    await seedUser('zoe', 'Zoe');
    await seedUser('amy', 'Amy');
    for (final id in ['zoe', 'amy']) {
      await db
          .collection('users')
          .doc(me)
          .collection('blockedUsers')
          .doc(id)
          .set({'createdAt': Timestamp.now()});
    }

    final container = _container(db);
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    container.listen(blockedUsersProvider, (_, __) {});

    List<AppUser> users = const [];
    for (var i = 0; i < 25; i++) {
      users = await container.read(blockedUsersProvider.future);
      if (users.length == 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(users.map((u) => u.displayName).toList(), ['Amy', 'Zoe']);
  });
}
