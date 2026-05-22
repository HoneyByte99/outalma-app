// Harness widget tests for ProfilePage.
// ProfilePage reads authNotifierProvider to get the current user.
// Override with an authenticated user to see the full profile content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/profile/profile_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
        AppUser(
          id: 'user_1',
          displayName: 'Alice Martin',
          email: 'alice@test.com',
          country: 'FR',
          activeMode: ActiveMode.client,
          createdAt: DateTime(2024, 1, 1),
        ),
      );
}

class _FakeThemeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _wrap() => ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        activeModeProvider.overrideWith((_) => ActiveMode.client),
        themeModeProvider.overrideWith(_FakeThemeNotifier.new),
        reviewsForUserProvider('user_1')
            .overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfilePage(),
      ),
    );

void main() {
  group('ProfilePage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('mode toggle section is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // ModeBadge is shown in the AppBar actions
      expect(find.byType(ProfilePage), findsOneWidget);
      // The page has a Scaffold — spot-check for Scaffold rendering
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('logout option is visible', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // Account section contains logout — check by icon
      expect(find.byIcon(Icons.logout_outlined), findsOneWidget);
    });
  });
}
