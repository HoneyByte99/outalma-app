// Harness widget tests for ProviderInboxPage.
// Overrides providerInboxProvider and providerActiveBookingsProvider to return
// empty lists so the empty state renders without hitting Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/features/provider/provider_inbox_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'prov_1',
      displayName: 'Provider User',
      email: 'prov@test.com',
      country: 'FR',
      activeMode: ActiveMode.provider,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

Widget _wrap() => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.provider),
    providerInboxProvider.overrideWith((_) => Stream.value([])),
    providerActiveBookingsProvider.overrideWith((_) => Stream.value([])),
    providerCompletedBookingsProvider.overrideWith((_) => Stream.value([])),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ProviderInboxPage(),
  ),
);

void main() {
  group('ProviderInboxPage', () {
    testWidgets('smoke - renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(ProviderInboxPage), findsOneWidget);
    });

    testWidgets('TabBar with three tabs is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(3));
    });

    testWidgets('empty state renders for requests tab', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // Empty state shows an icon - verify the page rendered at minimum
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('requests tab is pull-to-refreshable even when empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();
      // The empty state is wrapped in a RefreshIndicator so a provider can
      // always pull to retry, not only when a list already has content.
      expect(find.byType(RefreshIndicator), findsWidgets);
    });
  });
}
