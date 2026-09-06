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
  final otpRequests = <String>[];
  final verifyAttempts = <String>[];

  @override
  Future<AuthState> build() async => const AuthUnauthenticated();

  @override
  Future<void> requestPhoneOtp(
    String phoneE164, {
    String channel = 'sms',
  }) async {
    otpRequests.add(phoneE164);
  }

  @override
  Future<PhoneSignInResult> phoneSignInWithOtp(
    String phoneE164,
    String code,
  ) async {
    verifyAttempts.add(code);
    return const PhoneSignInResult(signedIn: true);
  }
}

class _FakeThemeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

void main() {
  late _FakeAuthNotifier auth;

  setUp(() => auth = _FakeAuthNotifier());

  Widget wrap() => ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => auth),
      themeModeProvider.overrideWith(_FakeThemeNotifier.new),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SignInPage(),
    ),
  );

  /// Reaches the OTP entry step: switches to the phone tab, types a number,
  /// then taps the CTA that sends the code (still the manual step 1, unlike
  /// step 2 below which auto-submits).
  Future<void> goToOtpStep(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.phone_outlined).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '770000001');
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();
  }

  group('SignInPage', () {
    testWidgets('smoke: renders without throwing', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('email TextField is present', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      // Email field is the first TextField visible in mail mode (default)
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('submit ElevatedButton is present', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('mail/phone toggle renders two tabs', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      // Labels are localized; assert on the stable tab icons instead.
      expect(find.byIcon(Icons.email_outlined), findsWidgets);
      expect(find.byIcon(Icons.phone_outlined), findsWidgets);
    });

    testWidgets(
      'typing the 6th digit of the SMS code auto-submits it, like the '
      'reference apps',
      (tester) async {
        await goToOtpStep(tester);
        expect(auth.otpRequests, ['+33770000001']);

        await tester.enterText(find.byType(TextField).first, '123456');
        await tester.pump();
        await tester.pump();

        expect(auth.verifyAttempts, ['123456']);
      },
    );

    testWidgets('an incomplete code triggers no verification attempt', (
      tester,
    ) async {
      await goToOtpStep(tester);

      await tester.enterText(find.byType(TextField).first, '12345');
      await tester.pump();
      await tester.pump();

      expect(auth.verifyAttempts, isEmpty);
    });
  });
}
