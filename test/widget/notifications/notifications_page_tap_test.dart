// Tap behavior on notifications_page.dart when the deep-link target
// (bookingId/chatId) has already been deleted. Before this fix, tapping such
// a notification pushed straight into the target route with no existence
// check (notifications_page.dart:177), landing the user on a chat/booking
// screen it cannot recover from cleanly. Covered here:
//   - tapping a healthy notification still navigates (regression guard)
//   - tapping a chat notification whose chat is gone does not navigate, and
//     shows a clear message instead
//   - tapping a booking notification whose booking is gone does not navigate,
//     and shows a clear message instead
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_notification.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/notifications/notifications_page.dart';

class _AuthenticatedNotifier extends AuthNotifier {
  _AuthenticatedNotifier(this._user);
  final AppUser _user;

  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

AppUser _makeUser() => AppUser(
  id: 'uid-1',
  displayName: 'Alice',
  email: 'alice@test.com',
  country: 'FR',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

void main() {
  late FakeFirebaseFirestore fakeDb;
  late AppUser user;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    user = _makeUser();
  });

  Future<void> writeNotification(AppNotification notif) =>
      FirestoreCollections.notifications(
        db: fakeDb,
        uid: user.id,
      ).doc(notif.id).set(notif);

  Widget wrap({required List<GoRoute> extraRoutes}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const NotificationsPage()),
        ...extraRoutes,
      ],
    );
    return ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _AuthenticatedNotifier(user)),
        firestoreProvider.overrideWithValue(fakeDb),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets(
    'tapping a notification whose chat still exists navigates there',
    (tester) async {
      await fakeDb.collection('chats').doc('c1').set({'participantIds': []});
      await writeNotification(
        AppNotification(
          id: 'n1',
          type: 'new_message',
          title: 'Nouveau message',
          body: 'Salut',
          read: false,
          createdAt: DateTime(2024, 6, 1).toUtc(),
          chatId: 'c1',
        ),
      );

      String? landed;
      await tester.pumpWidget(
        wrap(
          extraRoutes: [
            GoRoute(
              path: '/chat/:chatId',
              builder: (_, state) {
                landed = state.uri.toString();
                return const Scaffold(body: Text('chat'));
              },
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Nouveau message'));
      await tester.pumpAndSettle();

      expect(landed, '/chat/c1');
    },
  );

  testWidgets(
    'tapping a notification whose chat is gone does not navigate, and warns instead',
    (tester) async {
      // No chats/ghost-chat doc: the notification survived its target, exactly
      // the race the server-side cascade (onChatDeleted) closes but cannot
      // fully eliminate.
      await writeNotification(
        AppNotification(
          id: 'n1',
          type: 'new_message',
          title: 'Nouveau message',
          body: 'Salut',
          read: false,
          createdAt: DateTime(2024, 6, 1).toUtc(),
          chatId: 'ghost-chat',
        ),
      );

      String? landed;
      await tester.pumpWidget(
        wrap(
          extraRoutes: [
            GoRoute(
              path: '/chat/:chatId',
              builder: (_, state) {
                landed = state.uri.toString();
                return const Scaffold(body: Text('chat'));
              },
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Nouveau message'));
      await tester.pumpAndSettle();

      expect(landed, isNull, reason: 'must not land on the dead chat screen');
      expect(find.text('chat'), findsNothing);
      expect(find.text('Ce contenu n\'existe plus.'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a notification whose booking is gone does not navigate, and warns instead',
    (tester) async {
      await writeNotification(
        AppNotification(
          id: 'n1',
          type: 'booking_done',
          title: 'Reservation terminee',
          body: 'Termine',
          read: false,
          createdAt: DateTime(2024, 6, 1).toUtc(),
          bookingId: 'ghost-booking',
        ),
      );

      String? landed;
      await tester.pumpWidget(
        wrap(
          extraRoutes: [
            GoRoute(
              path: '/booking/:bookingId',
              builder: (_, state) {
                landed = state.uri.toString();
                return const Scaffold(body: Text('booking'));
              },
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Reservation terminee'));
      await tester.pumpAndSettle();

      expect(
        landed,
        isNull,
        reason: 'must not land on the dead booking screen',
      );
      expect(find.text('booking'), findsNothing);
      expect(find.text('Ce contenu n\'existe plus.'), findsOneWidget);
    },
  );
}
