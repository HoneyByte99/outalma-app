// Tests for notification_providers.dart application layer.
//
// Covered:
//   - notificationsProvider: returns empty stream when unauthenticated
//   - notificationsProvider: returns list from Firestore when authenticated
//   - notificationsProvider: list contains notifications with correct read flag
//   - unreadNotificationsCountProvider: returns 0 when unauthenticated
//   - unreadNotificationsCountProvider: counts only unread items
//   - unreadNotificationsCountProvider: returns 0 when all items are read
//   - markNotificationRead: sets read=true on target document
//   - markAllNotificationsRead: batch-marks all unread documents
//   - markAllNotificationsRead: no-op when all already read

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/notification/notification_providers.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_notification.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _AuthenticatedNotifier extends AuthNotifier {
  _AuthenticatedNotifier(this._user);
  final AppUser _user;

  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

class _UnauthenticatedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppUser _makeUser({String id = 'uid-1'}) => AppUser(
  id: id,
  displayName: 'Alice',
  email: 'alice@test.com',
  country: 'FR',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

AppNotification _makeNotification({
  String id = 'notif-1',
  bool read = false,
  String type = 'booking_accepted',
}) => AppNotification(
  id: id,
  type: type,
  title: 'Test',
  body: 'Test body',
  read: read,
  createdAt: DateTime(2024, 6, 1).toUtc(),
);

Future<void> _writeNotification(
  FakeFirebaseFirestore db,
  String uid,
  AppNotification notif,
) async {
  await FirestoreCollections.notifications(
    db: db,
    uid: uid,
  ).doc(notif.id).set(notif);
}

ProviderContainer _makeAuthenticatedContainer(
  AppUser user,
  FakeFirebaseFirestore db,
) => ProviderContainer(
  overrides: [
    authNotifierProvider.overrideWith(() => _AuthenticatedNotifier(user)),
    firestoreProvider.overrideWithValue(db),
  ],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  // -------------------------------------------------------------------------
  // notificationsProvider
  // -------------------------------------------------------------------------

  group('notificationsProvider', () {
    test('does not emit when unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UnauthenticatedNotifier()),
          firestoreProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      // Stream.empty() means the AsyncValue stays in loading - no data.
      final value = container.read(notificationsProvider);
      expect(value.hasValue, isFalse);
    });

    test('returns list of notifications for authenticated user', () async {
      final user = _makeUser();
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n1', read: false),
      );
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n2', read: true),
      );

      final container = _makeAuthenticatedContainer(user, fakeDb);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      final list = await container.read(notificationsProvider.future);

      expect(list, hasLength(2));
    });

    test('list contains notifications with correct read flag', () async {
      final user = _makeUser();
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n1', read: false),
      );
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n2', read: true),
      );

      final container = _makeAuthenticatedContainer(user, fakeDb);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      final list = await container.read(notificationsProvider.future);

      final n1 = list.firstWhere((n) => n.id == 'n1');
      final n2 = list.firstWhere((n) => n.id == 'n2');
      expect(n1.read, isFalse);
      expect(n2.read, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // unreadNotificationsCountProvider
  // -------------------------------------------------------------------------

  group('unreadNotificationsCountProvider', () {
    test('returns 0 when unauthenticated (no data)', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UnauthenticatedNotifier()),
          firestoreProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    test('counts only unread notifications', () async {
      final user = _makeUser();
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n1', read: false),
      );
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n2', read: false),
      );
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n3', read: true),
      );

      final container = _makeAuthenticatedContainer(user, fakeDb);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(notificationsProvider.future);

      expect(container.read(unreadNotificationsCountProvider), 2);
    });

    test('returns 0 when all notifications are read', () async {
      final user = _makeUser();
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n1', read: true),
      );
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: 'n2', read: true),
      );

      final container = _makeAuthenticatedContainer(user, fakeDb);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(notificationsProvider.future);

      expect(container.read(unreadNotificationsCountProvider), 0);
    });
  });

  // -------------------------------------------------------------------------
  // markNotificationRead
  // -------------------------------------------------------------------------

  group('markNotificationRead', () {
    test('sets read=true on the target document', () async {
      final user = _makeUser();
      const notifId = 'notif-mark';
      await _writeNotification(
        fakeDb,
        user.id,
        _makeNotification(id: notifId, read: false),
      );

      await markNotificationRead(db: fakeDb, uid: user.id, notifId: notifId);

      final snap = await FirestoreCollections.notifications(
        db: fakeDb,
        uid: user.id,
      ).doc(notifId).get();
      expect(snap.data()?.read, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // markAllNotificationsRead
  // -------------------------------------------------------------------------

  group('markAllNotificationsRead', () {
    test('batch-marks all unread notifications as read', () async {
      final user = _makeUser();
      final n1 = _makeNotification(id: 'a1', read: false);
      final n2 = _makeNotification(id: 'a2', read: false);
      await _writeNotification(fakeDb, user.id, n1);
      await _writeNotification(fakeDb, user.id, n2);

      await markAllNotificationsRead(
        db: fakeDb,
        uid: user.id,
        notifications: [n1, n2],
      );

      final col = FirestoreCollections.notifications(db: fakeDb, uid: user.id);
      final s1 = await col.doc('a1').get();
      final s2 = await col.doc('a2').get();
      expect(s1.data()?.read, isTrue);
      expect(s2.data()?.read, isTrue);
    });

    test('is a no-op when all notifications are already read', () async {
      final user = _makeUser();
      final n1 = _makeNotification(id: 'b1', read: true);
      await _writeNotification(fakeDb, user.id, n1);

      // Should complete without throwing.
      await expectLater(
        markAllNotificationsRead(db: fakeDb, uid: user.id, notifications: [n1]),
        completes,
      );
    });
  });
}
