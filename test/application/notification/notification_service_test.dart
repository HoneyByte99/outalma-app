// Tests for NotificationService.initialize() — the client-side FCM token
// registration logic. FirebaseMessaging is mocked (mocktail); Firestore is a
// fake. Platform is forced to Android so the iOS APNS poll loop is skipped
// (that 6s wait is native timing, not logic we can unit-test here).
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/notification/notification_service.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockSettings extends Mock implements NotificationSettings {}

void main() {
  late _MockMessaging messaging;
  late FakeFirebaseFirestore db;
  late StreamController<String> tokenRefresh;
  const uid = 'user-1';

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messaging = _MockMessaging();
    db = FakeFirebaseFirestore();
    tokenRefresh = StreamController<String>.broadcast();
    when(() => messaging.onTokenRefresh).thenAnswer((_) => tokenRefresh.stream);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    tokenRefresh.close();
  });

  NotificationService service() =>
      NotificationService(messaging: messaging, db: db, uid: uid);

  void stubPermission(AuthorizationStatus status) {
    final settings = _MockSettings();
    when(() => settings.authorizationStatus).thenReturn(status);
    when(
      () => messaging.requestPermission(
        alert: any(named: 'alert'),
        badge: any(named: 'badge'),
        sound: any(named: 'sound'),
      ),
    ).thenAnswer((_) async => settings);
  }

  Future<String?> savedToken() async {
    final snap = await db.collection('users').doc(uid).get();
    return snap.data()?['pushToken'] as String?;
  }

  test('saves the FCM token to the user doc on the happy path', () async {
    stubPermission(AuthorizationStatus.authorized);
    when(() => messaging.getToken()).thenAnswer((_) async => 'tok-abc');

    await service().initialize();

    expect(await savedToken(), 'tok-abc');
  });

  test('does NOT register a token when permission is denied', () async {
    stubPermission(AuthorizationStatus.denied);

    await service().initialize();

    verifyNever(() => messaging.getToken());
    expect(await savedToken(), isNull);
  });

  test('treats notDetermined like denied (no token yet)', () async {
    stubPermission(AuthorizationStatus.notDetermined);

    await service().initialize();

    verifyNever(() => messaging.getToken());
    expect(await savedToken(), isNull);
  });

  test('saves a late token delivered via onTokenRefresh', () async {
    stubPermission(AuthorizationStatus.authorized);
    // getToken returns null at init (APNS not ready), token arrives later.
    when(() => messaging.getToken()).thenAnswer((_) async => null);

    await service().initialize();
    expect(await savedToken(), isNull);

    tokenRefresh.add('tok-late');
    await Future<void>.delayed(Duration.zero);

    expect(await savedToken(), 'tok-late');
  });

  test('does not crash and saves nothing when getToken throws', () async {
    stubPermission(AuthorizationStatus.authorized);
    when(() => messaging.getToken()).thenThrow(
      FirebaseException(plugin: 'messaging', code: 'apns-token-not-set'),
    );

    await service().initialize();

    expect(await savedToken(), isNull);
    // onTokenRefresh still wired up — a later token is still captured.
    tokenRefresh.add('tok-recovered');
    await Future<void>.delayed(Duration.zero);
    expect(await savedToken(), 'tok-recovered');
  });

  test(
    'writes a notifDebug diagnostic with the resolved auth status',
    () async {
      stubPermission(AuthorizationStatus.authorized);
      when(() => messaging.getToken()).thenAnswer((_) async => 'tok');

      await service().initialize();

      final snap = await db.collection('users').doc(uid).get();
      final debug = snap.data()?['notifDebug'] as Map<String, dynamic>?;
      expect(debug, isNotNull);
      expect(debug?['authStatus'], contains('authorized'));
    },
  );
}
