// Harness widget tests for SignInPage.
// Strategy: override authNotifierProvider + themeModeProvider to bypass
// Firebase. Verify smoke render, email field, and submit button presence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/features/auth/sign_in_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

class _FakeThemeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _wrap() => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    themeModeProvider.overrideWith(_FakeThemeNotifier.new),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const SignInPage(),
  ),
);

void main() {
  group('SignInPage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('email TextField is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // Email field is the first TextField visible in mail mode (default)
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('submit ElevatedButton is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('mail/phone toggle renders two tabs', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // Labels are localized; assert on the stable tab icons instead.
      expect(find.byIcon(Icons.email_outlined), findsWidgets);
      expect(find.byIcon(Icons.phone_outlined), findsWidgets);
    });
  });
}
