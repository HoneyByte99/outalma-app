// Harness widget tests for SignInPage.
// Strategy: override authNotifierProvider + themeModeProvider to bypass
// Firebase. Verify smoke render, email field, and submit button presence.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/auth/phone_otp_port.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/domain/auth/otp_request_error.dart';
import 'package:outalma_app/src/features/auth/sign_in_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final otpRequests = <String>[];
  final verifyAttempts = <String>[];

  /// What the next send answers. The default is what the real server sends on
  /// a first successful request: the first backoff step, 60 s.
  OtpRequestOutcome outcome = const OtpRequestOutcome(retryAfterMs: 60000);

  /// Set to replay a server refusal instead of a success.
  OtpRequestError? refusal;

  @override
  Future<AuthState> build() async => const AuthUnauthenticated();

  /// Set to hold the call open, so a test can dispose the page while the
  /// request is still in flight.
  Completer<OtpRequestOutcome>? pending;

  @override
  Future<OtpRequestOutcome> requestPhoneOtp(String phoneE164) {
    otpRequests.add(phoneE164);
    final held = pending;
    if (held != null) return held.future;
    final r = refusal;
    if (r != null) return Future<OtpRequestOutcome>.error(r);
    return Future<OtpRequestOutcome>.value(outcome);
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
      // Pinned so the countdown assertions below read a known catalogue.
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SignInPage(),
    ),
  );

  /// Reaches the OTP entry step: switches to the phone tab, types a number,
  /// then taps the CTA that sends the code (still the manual step 1, unlike
  /// step 2 below which auto-submits).
  Future<void> goToOtpStep(WidgetTester tester) async {
    // A window tall enough to hold the OTP step whole. The screen scrolls, and
    // a control below the fold cannot be tapped, so the default window would
    // make the resend assertions fail on geometry rather than on behaviour.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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

    group('resend brake', () {
      /// The resend control. The OTP step carries several TextButtons (edit
      /// the number, the sign-up prompt), so it is located by its own label,
      /// whose two forms both start with the same verb.
      Finder resendButton() => find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('Renvoyer') ?? false),
        ),
        matching: find.byType(TextButton),
      );

      testWidgets('locks the resend button for the delay the SERVER gave', (
        tester,
      ) async {
        auth.outcome = const OtpRequestOutcome(retryAfterMs: 60000);
        await goToOtpStep(tester);

        expect(find.text('Renvoyer dans 60s'), findsOneWidget);
        expect(
          tester.widget<TextButton>(resendButton()).onPressed,
          isNull,
          reason: 'a labelled countdown over a live button is a lie',
        );
      });

      testWidgets('counts down and hands the button back', (tester) async {
        auth.outcome = const OtpRequestOutcome(retryAfterMs: 3000);
        await goToOtpStep(tester);
        expect(find.text('Renvoyer dans 3s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Renvoyer dans 2s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Renvoyer le code'), findsOneWidget);
        expect(tester.widget<TextButton>(resendButton()).onPressed, isNotNull);

        // And the button works again: one more request reaches the notifier.
        await tester.tap(resendButton());
        await tester.pump();
        await tester.pump();
        expect(auth.otpRequests.length, 2);
      });

      testWidgets('never invents a delay the server did not send', (
        tester,
      ) async {
        auth.outcome = const OtpRequestOutcome(retryAfterMs: null);
        await goToOtpStep(tester);

        expect(find.text('Renvoyer le code'), findsOneWidget);
        expect(tester.widget<TextButton>(resendButton()).onPressed, isNotNull);
      });

      testWidgets('a REFUSAL starts the countdown too, not just a success', (
        tester,
      ) async {
        // Otherwise the next tap walks straight back into the same wall and
        // spends another server round trip to be told the same thing.
        auth.outcome = const OtpRequestOutcome(retryAfterMs: null);
        await goToOtpStep(tester);
        auth.refusal = const OtpRequestError(
          OtpRequestErrorKind.backoff,
          retryAfterMs: 45000,
        );

        await tester.tap(resendButton());
        await tester.pump();
        await tester.pump();

        expect(find.text('Renvoyer dans 45s'), findsOneWidget);
        expect(tester.widget<TextButton>(resendButton()).onPressed, isNull);
      });

      testWidgets('a refusal landing after the user left does not throw', (
        tester,
      ) async {
        // The countdown starts on the refusal path too, and that path has no
        // `mounted` guard of its own: without the one inside the mixin, this
        // is setState on a disposed State, thrown out of an async gap nobody
        // catches.
        final pending = Completer<OtpRequestOutcome>();
        auth.pending = pending;
        await goToOtpStep(tester);

        await tester.pumpWidget(const SizedBox());
        pending.completeError(
          const OtpRequestError(
            OtpRequestErrorKind.backoff,
            retryAfterMs: 60000,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('says WHY, and differently for each refusal', (tester) async {
        // The whole point of the typed error: "wait" and "this country is not
        // served" are not the same sentence, and the second is not a wait.
        auth.outcome = const OtpRequestOutcome(retryAfterMs: null);
        await goToOtpStep(tester);
        auth.refusal = const OtpRequestError(
          OtpRequestErrorKind.prefixNotServed,
        );

        await tester.tap(resendButton());
        await tester.pump();
        await tester.pump();

        expect(
          find.textContaining("Ce pays n'est pas encore desservi"),
          findsOneWidget,
        );
        expect(
          tester.widget<TextButton>(resendButton()).onPressed,
          isNotNull,
          reason: 'waiting cannot fix an unserved country',
        );
      });
    });

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
