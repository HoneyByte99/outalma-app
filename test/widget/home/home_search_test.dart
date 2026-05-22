// Harness widget tests for HomePage.
// Overrides: authNotifierProvider (unauthenticated), serviceListProvider
// (empty list → renders empty state), activeModeProvider.
// The search TextField is rendered unconditionally in _SearchBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

Widget _wrap({List<Service> services = const []}) => ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        activeModeProvider.overrideWith((_) => ActiveMode.client),
        serviceListProvider.overrideWith((_) => Stream.value(services)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomePage(),
      ),
    );

void main() {
  group('HomePage — search', () {
    testWidgets('smoke — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('search TextField is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('empty state renders when service list is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(services: []));
      // Allow stream to emit
      await tester.pump();
      await tester.pump();
      // Empty state shows a search-off icon
      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
    });
  });
}
