// Widget tests for the provider-only "Identity verification" block on the
// ProfilePage. The block must (1) appear only in provider mode and (2) read the
// connected provider's identity trust state, mapping it to the right label.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/identity_trust_status.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/profile/profile_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'user_1',
      displayName: 'Alice Martin',
      email: 'alice@test.com',
      country: 'SN',
      activeMode: ActiveMode.provider,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

class _FakeThemeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _wrap({
  required ActiveMode mode,
  required IdentityTrustStatus? status,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => mode),
    themeModeProvider.overrideWith(_FakeThemeNotifier.new),
    reviewsForUserProvider('user_1').overrideWith((_) => Stream.value([])),
    identityTrustProvider('user_1').overrideWith((_) => Stream.value(status)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ProfilePage(),
  ),
);

void main() {
  group('ProfilePage identity verification block', () {
    testWidgets('hidden in client mode', (tester) async {
      await tester.pumpWidget(
        _wrap(mode: ActiveMode.client, status: IdentityTrustStatus.verified),
      );
      await tester.pump();
      await tester.pump();
      // Section label is uppercased by _SectionLabel.
      expect(find.text('IDENTITY VERIFICATION'), findsNothing);
      // The verified label must not surface in client mode.
      expect(find.text('Verified profile'), findsNothing);
    });

    testWidgets('shown in provider mode, not verified state', (tester) async {
      await tester.pumpWidget(_wrap(mode: ActiveMode.provider, status: null));
      await tester.pump();
      await tester.pump();
      expect(find.text('IDENTITY VERIFICATION'), findsOneWidget);
      // Null state collapses to the neutral "verify" affordance (fail-closed).
      expect(find.text('Verify my identity'), findsOneWidget);
    });

    testWidgets('provider mode, pending state', (tester) async {
      await tester.pumpWidget(
        _wrap(mode: ActiveMode.provider, status: IdentityTrustStatus.pending),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('IDENTITY VERIFICATION'), findsOneWidget);
      expect(find.text('Verification under way'), findsOneWidget);
    });

    testWidgets('provider mode, verified state', (tester) async {
      await tester.pumpWidget(
        _wrap(mode: ActiveMode.provider, status: IdentityTrustStatus.verified),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('IDENTITY VERIFICATION'), findsOneWidget);
      expect(find.text('Verified profile'), findsOneWidget);
    });
  });
}
