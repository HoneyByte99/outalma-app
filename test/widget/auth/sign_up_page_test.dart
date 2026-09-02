// Harness widget tests for SignUpPage.
// Strategy: override authNotifierProvider + themeModeProvider to bypass
// Firebase. Verify smoke render, name field, and submit button presence.
//
// The gender block below covers BOTH sign-up paths on purpose. The screen has
// two of them, email/password and phone/OTP, and a mandatory field enforced on
// one only would leave half the corpus without an answer, which is exactly the
// hole this increment set out to close.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/features/auth/sign_up_page.dart';

/// Records what the screen sent, and sends nothing anywhere. Every method the
/// two paths can reach is overridden, so a missing gate shows up as a recorded
/// call rather than as a Firebase error.
class _FakeAuthNotifier extends AuthNotifier {
  final List<Gender?> emailSignUps = [];
  final List<String> otpRequests = [];
  final List<Gender?> phoneSignUps = [];

  @override
  Future<AuthState> build() async => const AuthUnauthenticated();

  @override
  Future<void> signUpWithEmailPassword({
    required String displayName,
    required String email,
    required String password,
    required Gender gender,
  }) async {
    emailSignUps.add(gender);
  }

  @override
  Future<void> requestPhoneOtp(
    String phoneE164, {
    String channel = 'sms',
  }) async {
    otpRequests.add(phoneE164);
  }

  @override
  Future<void> phoneSignUpWithOtp({
    required String phoneE164,
    required String code,
    required String displayName,
    required String country,
    required Gender gender,
  }) async {
    phoneSignUps.add(gender);
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
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SignUpPage(),
    ),
  );

  /// A window tall enough to hold the whole form. The screen scrolls, and a
  /// control below the fold cannot be tapped, so a short window would make
  /// these tests fail on geometry rather than on behaviour.
  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pump();
  }

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();
  }

  group('SignUpPage', () {
    testWidgets('smoke - renders without throwing', (tester) async {
      await pumpForm(tester);
      expect(find.byType(SignUpPage), findsOneWidget);
    });

    testWidgets('at least one TextField (name/email) is present', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('submit ElevatedButton is present', (tester) async {
      await pumpForm(tester);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('mail/phone toggle renders two tabs', (tester) async {
      await pumpForm(tester);
      // Labels are localized; assert on the stable tab icons instead.
      expect(find.byIcon(Icons.email_outlined), findsWidgets);
      expect(find.byIcon(Icons.phone_outlined), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // The declared gender, on the EMAIL path
  // ---------------------------------------------------------------------------
  group('gender on the email path', () {
    testWidgets('the control is on the form, with nothing preselected', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(find.byType(GenderSelector), findsOneWidget);
      expect(
        tester.widget<GenderSelector>(find.byType(GenderSelector)).value,
        isNull,
        reason:
            'a preselected control harvests a default from whoever did not '
            'look, and this value is published beside their name',
      );
    });

    testWidgets('a complete form WITHOUT a gender creates no account', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Awa Cisse');
      await tester.enterText(find.byType(TextField).at(1), 'awa@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'motdepasse');
      await tester.enterText(find.byType(TextField).at(3), 'motdepasse');
      await acceptTerms(tester);

      await submit(tester);

      expect(auth.emailSignUps, isEmpty);
      expect(
        find.text('Veuillez indiquer si vous êtes un homme ou une femme.'),
        findsOneWidget,
      );
    });

    testWidgets('the same form WITH a gender carries the chosen value', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Awa Cisse');
      await tester.enterText(find.byType(TextField).at(1), 'awa@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'motdepasse');
      await tester.enterText(find.byType(TextField).at(3), 'motdepasse');
      await tester.tap(find.text('Femme'));
      await tester.pump();
      await acceptTerms(tester);

      await submit(tester);

      expect(auth.emailSignUps, [Gender.female]);
    });

    testWidgets('the male option carries male, not just "not female"', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Moussa Diallo');
      await tester.enterText(find.byType(TextField).at(1), 'm@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'motdepasse');
      await tester.enterText(find.byType(TextField).at(3), 'motdepasse');
      await tester.tap(find.text('Homme'));
      await tester.pump();
      await acceptTerms(tester);

      await submit(tester);

      expect(auth.emailSignUps, [Gender.male]);
    });
  });

  // ---------------------------------------------------------------------------
  // The declared gender, on the PHONE path
  // ---------------------------------------------------------------------------
  group('gender on the phone path', () {
    Future<void> goToPhoneDetails(WidgetTester tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Téléphone'));
      await tester.pump();
    }

    Future<void> fillPhoneDetails(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'Awa Cisse');
      await tester.enterText(find.byType(TextField).at(1), '770000001');
      await tester.pump();
      await acceptTerms(tester);
    }

    testWidgets('the control is on this path too', (tester) async {
      await goToPhoneDetails(tester);
      expect(find.byType(GenderSelector), findsOneWidget);
    });

    testWidgets('no gender means no OTP is even sent', (tester) async {
      // Gated on the details step rather than at sign-up: an SMS costs money
      // and the form cannot conclude without the field anyway.
      await goToPhoneDetails(tester);
      await fillPhoneDetails(tester);

      await submit(tester);

      expect(auth.otpRequests, isEmpty);
      expect(
        find.text('Veuillez indiquer si vous êtes un homme ou une femme.'),
        findsOneWidget,
      );
    });

    testWidgets('with a gender the code goes out and the value reaches signup', (
      tester,
    ) async {
      await goToPhoneDetails(tester);
      await fillPhoneDetails(tester);
      await tester.tap(find.text('Homme'));
      await tester.pump();

      await submit(tester);
      expect(auth.otpRequests, ['+33770000001']);

      // Step 2: the OTP screen has no gender control, so this proves the value
      // chosen on step 1 survives the transition and reaches the account.
      await tester.enterText(find.byType(TextField).first, '123456');
      await submit(tester);

      expect(auth.phoneSignUps, [Gender.male]);
    });
  });
}
