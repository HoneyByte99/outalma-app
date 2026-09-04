// A notification written before the sender-identity migration (2026-09) has
// no senderId/senderName: the field simply never existed. This proves the
// list renders such a notification exactly as before - the bare legacy
// title, the original body, no "null" string, no blank/broken tile - since
// notify.ts's titleWithSender falls back to the untouched base title when it
// cannot resolve a name, and the client never re-derives one at render time.
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
  testWidgets(
    'a notification with no senderId/senderName renders its bare legacy title and body, with no crash',
    (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      final user = _makeUser();

      await FirestoreCollections.notifications(db: fakeDb, uid: user.id)
          .doc('n1')
          .set(
            AppNotification(
              id: 'n1',
              type: 'booking_accepted',
              title: 'Demande acceptée',
              body: 'Votre prestataire a accepté votre demande.',
              read: false,
              createdAt: DateTime(2024, 6, 1).toUtc(),
              // No senderId/senderName: exactly the shape of the 391
              // pre-migration notifications in production.
            ),
          );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const NotificationsPage()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => _AuthenticatedNotifier(user),
            ),
            firestoreProvider.overrideWithValue(fakeDb),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Demande acceptée'), findsOneWidget);
      expect(
        find.text('Votre prestataire a accepté votre demande.'),
        findsOneWidget,
      );
      // The literal string "null" must never leak onto the tile: neither
      // widget construction nor rendering throws for the missing fields.
      expect(find.textContaining('null'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
