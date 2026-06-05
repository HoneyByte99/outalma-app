// Harness widget tests for SignUpPage.
// Strategy: override authNotifierProvider + themeModeProvider to bypass
// Firebase. Verify smoke render, name field, and submit button presence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/features/auth/sign_up_page.dart';

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
    home: const SignUpPage(),
  ),
);

void main() {
  group('SignUpPage', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(SignUpPage), findsOneWidget);
    });

    testWidgets('at least one TextField (name/email) is present', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
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
      expect(find.text('Mail'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
    });
  });
}
