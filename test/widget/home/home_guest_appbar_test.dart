// Guest vs authenticated home AppBar (Lot 6 polish).
//
// A guest has no mode to toggle and no notifications, so the AppBar shows a
// sign-in action instead of the ModeBadge + notifications bell. An
// authenticated user still gets the badge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/notification/notification_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/home/home_page.dart';
import 'package:outalma_app/src/features/shared/mode_badge.dart';

class _GuestNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

class _AuthedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'u1',
      displayName: 'Awa',
      email: 'awa@test.com',
      country: 'SN',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

Widget _wrap({required bool guest}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(
      () => guest ? _GuestNotifier() : _AuthedNotifier(),
    ),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    serviceListProvider.overrideWith((_) => Stream.value(const [])),
    notificationsProvider.overrideWith((_) => Stream.value(const [])),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomePage(),
  ),
);

void main() {
  testWidgets('guest AppBar shows a sign-in action, no mode badge', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(guest: true));
    await tester.pump();

    expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    expect(find.byType(ModeBadge), findsNothing);
  });

  testWidgets('authenticated AppBar shows the mode badge, no sign-in action', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(guest: false));
    await tester.pump();

    expect(find.byType(ModeBadge), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsNothing);
  });
}
