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
    testWidgets('smoke - renders without throwing', (tester) async {
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

    testWidgets('CTA is disabled until the terms checkbox is ticked', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      ElevatedButton cta() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      // Consent not yet given: account creation must be blocked.
      expect(cta().onPressed, isNull);

      // Tick the terms + privacy checkbox and the CTA becomes enabled. The form
      // scrolls, so bring the checkbox into view before tapping it.
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(cta().onPressed, isNotNull);
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
