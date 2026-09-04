// Tests for notification_tap_guard.dart, the guard app.dart's
// _handleNotificationTap uses before pushing a system-notification deep link
// (cold start / background tap, via FirebaseMessaging.onMessageOpenedApp and
// getInitialMessage). Before this fix, that path resolved the route with
// notificationRouteForData and pushed unconditionally: a tap on a system
// notification whose chat/booking was already deleted server-side landed on
// a dead screen with no explanation, unlike the in-app notifications list
// (notifications_page.dart), which was already guarded.
//
// Covered:
//   - notificationTargetExistsForData: true/false mirroring
//     notificationRouteForData's chatId/bookingId extraction (empty strings
//     don't count, chat wins over booking)
//   - showNotificationTargetGoneMessage: renders the localized message via
//     the messenger key
//   - end-to-end wiring (the same two functions composed the way app.dart
//     composes them): a gone target does not navigate and shows the message;
//     a healthy target still navigates (regression guard)
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/app/notification_tap_guard.dart';

const _goneMessage = "Ce contenu n'existe plus.";

void main() {
  group('notificationTargetExistsForData', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    test('true when the chat doc exists', () async {
      await fakeDb.collection('chats').doc('c1').set({'participantIds': []});

      expect(
        await notificationTargetExistsForData(
          db: fakeDb,
          data: {'chatId': 'c1'},
        ),
        isTrue,
      );
    });

    test('false when the chat doc has been deleted', () async {
      expect(
        await notificationTargetExistsForData(
          db: fakeDb,
          data: {'chatId': 'ghost-chat'},
        ),
        isFalse,
      );
    });

    test('false when the booking doc has been deleted', () async {
      expect(
        await notificationTargetExistsForData(
          db: fakeDb,
          data: {'bookingId': 'ghost-booking'},
        ),
        isFalse,
      );
    });

    test('true when the booking doc exists', () async {
      await fakeDb.collection('bookings').doc('b1').set({'status': 'done'});

      expect(
        await notificationTargetExistsForData(
          db: fakeDb,
          data: {'bookingId': 'b1'},
        ),
        isTrue,
      );
    });

    test(
      'checks the chat, not the booking, when both ids are present',
      () async {
        await fakeDb.collection('bookings').doc('b1').set({'status': 'done'});
        // No chats/c1 doc: chat wins per notificationRouteForData's precedence,
        // so this must resolve against the (missing) chat, not the (present)
        // booking.
        expect(
          await notificationTargetExistsForData(
            db: fakeDb,
            data: {'chatId': 'c1', 'bookingId': 'b1'},
          ),
          isFalse,
        );
      },
    );

    test(
      'ignores an empty-string chatId and falls back to bookingId',
      () async {
        await fakeDb.collection('bookings').doc('b1').set({'status': 'done'});

        expect(
          await notificationTargetExistsForData(
            db: fakeDb,
            data: {'chatId': '', 'bookingId': 'b1'},
          ),
          isTrue,
        );
      },
    );

    test('true when neither id is present (nothing to check)', () async {
      expect(
        await notificationTargetExistsForData(db: fakeDb, data: {'type': 'x'}),
        isTrue,
      );
    });
  });

  group('showNotificationTargetGoneMessage', () {
    testWidgets('renders the localized target-gone message', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          scaffoldMessengerKey: messengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      showNotificationTargetGoneMessage(messengerKey);
      await tester.pump();

      expect(find.text(_goneMessage), findsOneWidget);
    });

    testWidgets('is a no-op when the messenger has no current state', (
      tester,
    ) async {
      final unattachedKey = GlobalKey<ScaffoldMessengerState>();

      // Must not throw even though nothing was ever pumped with this key.
      expect(
        () => showNotificationTargetGoneMessage(unattachedKey),
        returnsNormally,
      );
    });
  });

  group('end-to-end: guard wired the way app.dart wires it', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    Future<void> pumpAppLike(
      WidgetTester tester,
      GlobalKey<ScaffoldMessengerState> messengerKey,
      GoRouter router,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          scaffoldMessengerKey: messengerKey,
          routerConfig: router,
        ),
      );
      await tester.pump();
    }

    // Mirrors app.dart's _handleNotificationTap tail: probe, then either
    // push the resolved route or show the gone message. Exercising the real
    // exported functions this way proves the composition app.dart relies on,
    // without needing to drive FirebaseMessaging's platform channels (no
    // mock exists for those in this codebase; NotificationService takes an
    // injected instance for exactly that reason, but app.dart's tap listeners
    // are wired to the static FirebaseMessaging.instance singleton).
    Future<void> handleTapLike(
      GoRouter router,
      GlobalKey<ScaffoldMessengerState> messengerKey,
      String route,
      Map<String, dynamic> data,
    ) async {
      final exists = await notificationTargetExistsForData(
        db: fakeDb,
        data: data,
      );
      if (!exists) {
        showNotificationTargetGoneMessage(messengerKey);
        return;
      }
      unawaited(router.push(route));
    }

    testWidgets('a gone chat target does not navigate and shows the message', (
      tester,
    ) async {
      String? landed;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/chat/:chatId',
            builder: (_, state) {
              landed = state.uri.toString();
              return const Scaffold(body: Text('chat'));
            },
          ),
        ],
      );
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await pumpAppLike(tester, messengerKey, router);

      await handleTapLike(router, messengerKey, '/chat/ghost-chat', {
        'chatId': 'ghost-chat',
      });
      await tester.pumpAndSettle();

      expect(landed, isNull, reason: 'must not land on the dead chat screen');
      expect(find.text('chat'), findsNothing);
      expect(find.text(_goneMessage), findsOneWidget);
    });

    testWidgets(
      'a gone booking target does not navigate and shows the message',
      (tester) async {
        String? landed;
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('home')),
            ),
            GoRoute(
              path: '/bookings/:bookingId',
              builder: (_, state) {
                landed = state.uri.toString();
                return const Scaffold(body: Text('booking'));
              },
            ),
          ],
        );
        final messengerKey = GlobalKey<ScaffoldMessengerState>();
        await pumpAppLike(tester, messengerKey, router);

        await handleTapLike(router, messengerKey, '/bookings/ghost-booking', {
          'bookingId': 'ghost-booking',
        });
        await tester.pumpAndSettle();

        expect(
          landed,
          isNull,
          reason: 'must not land on the dead booking screen',
        );
        expect(find.text('booking'), findsNothing);
        expect(find.text(_goneMessage), findsOneWidget);
      },
    );

    testWidgets('a healthy target still navigates (regression guard)', (
      tester,
    ) async {
      await fakeDb.collection('chats').doc('c1').set({'participantIds': []});
      String? landed;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/chat/:chatId',
            builder: (_, state) {
              landed = state.uri.toString();
              return const Scaffold(body: Text('chat'));
            },
          ),
        ],
      );
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await pumpAppLike(tester, messengerKey, router);

      await handleTapLike(router, messengerKey, '/chat/c1', {'chatId': 'c1'});
      await tester.pumpAndSettle();

      expect(landed, '/chat/c1');
      expect(find.text(_goneMessage), findsNothing);
    });
  });
}
