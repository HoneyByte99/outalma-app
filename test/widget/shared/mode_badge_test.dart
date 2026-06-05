// Widget tests for ModeBadge.
// ModeBadge reads activeModeProvider (derived from authNotifierProvider) and
// renders the current mode label.
//
// Strategy: override activeModeProvider directly with a fixed value so we
// avoid deep-mocking FirebaseAuth + Firestore inside AuthNotifier.build().

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/shared/mode_badge.dart';
import 'package:outalma_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Minimal fake AuthNotifier that returns a pre-set auth state, bypassing
// all Firebase dependencies.
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._state);
  final AuthState _state;

  @override
  Future<AuthState> build() async => _state;
}

AppUser _makeUser({ActiveMode mode = ActiveMode.client}) => AppUser(
  id: 'test_uid',
  displayName: 'Test User',
  email: 'test@example.com',
  country: 'FR',
  activeMode: mode,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

Widget _wrap({required ActiveMode mode}) {
  final user = _makeUser(mode: mode);
  final authState = AuthAuthenticated(user);

  return ProviderScope(
    overrides: [
      // Override the AsyncNotifier so build() never touches Firebase
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(authState)),
      // Override the derived provider to return the mode directly
      activeModeProvider.overrideWith((_) => mode),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: ModeBadge(),
        ),
      ),
    ),
  );
}

void main() {
  group('ModeBadge', () {
    testWidgets('renders without throwing in client mode', (tester) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.client));
      await tester.pump();
      expect(find.byType(ModeBadge), findsOneWidget);
    });

    testWidgets('renders without throwing in provider mode', (tester) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.provider));
      await tester.pump();
      expect(find.byType(ModeBadge), findsOneWidget);
    });

    testWidgets('shows "Client" label when mode is ActiveMode.client', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.client));
      await tester.pump();
      // l10n key modeClient = "Client" (from app_en.arb)
      expect(find.text('Client'), findsOneWidget);
    });

    testWidgets('shows "Provider" label when mode is ActiveMode.provider', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.provider));
      await tester.pump();
      // l10n key modeProvider = "Provider" (from app_en.arb)
      expect(find.text('Provider'), findsOneWidget);
    });

    testWidgets('shows swap icon in client mode', (tester) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.client));
      await tester.pump();
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows swap icon in provider mode', (tester) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.provider));
      await tester.pump();
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    });
  });
}
