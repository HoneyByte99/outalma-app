// Harness widget tests for FinalizeSignUpPage (consent recovery flow).
// Strategy: override authNotifierProvider with a fake that records the retry /
// signOut calls (and can be made to fail) so no Firebase is needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/features/auth/finalize_sign_up_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({this.retryThrows = false});

  final bool retryThrows;
  int retryCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AuthState> build() async => const AuthUnauthenticated();

  @override
  Future<void> retryConsentFinalization() async {
    retryCalls++;
    if (retryThrows) {
      throw StateError('still offline');
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

Widget _wrap(_FakeAuthNotifier notifier) => ProviderScope(
  overrides: [authNotifierProvider.overrideWith(() => notifier)],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const FinalizeSignUpPage(),
  ),
);

void main() {
  group('FinalizeSignUpPage', () {
    testWidgets('smoke - renders retry and sign-out actions', (tester) async {
      await tester.pumpWidget(_wrap(_FakeAuthNotifier()));
      await tester.pump();
      expect(find.byType(FinalizeSignUpPage), findsOneWidget);
      expect(find.text('Reessayer'), findsOneWidget);
      expect(find.text('Se deconnecter'), findsOneWidget);
    });

    testWidgets('tapping Reessayer retries consent finalization', (
      tester,
    ) async {
      final notifier = _FakeAuthNotifier();
      await tester.pumpWidget(_wrap(notifier));
      await tester.pump();
      await tester.tap(find.text('Reessayer'));
      await tester.pumpAndSettle();
      expect(notifier.retryCalls, 1);
    });

    testWidgets('shows an error message when the retry fails', (tester) async {
      final notifier = _FakeAuthNotifier(retryThrows: true);
      await tester.pumpWidget(_wrap(notifier));
      await tester.pump();
      await tester.tap(find.text('Reessayer'));
      await tester.pumpAndSettle();
      expect(notifier.retryCalls, 1);
      expect(find.textContaining('echoue'), findsOneWidget);
    });

    testWidgets('tapping Se deconnecter signs out', (tester) async {
      final notifier = _FakeAuthNotifier();
      await tester.pumpWidget(_wrap(notifier));
      await tester.pump();
      await tester.tap(find.text('Se deconnecter'));
      await tester.pumpAndSettle();
      expect(notifier.signOutCalls, 1);
    });
  });
}
