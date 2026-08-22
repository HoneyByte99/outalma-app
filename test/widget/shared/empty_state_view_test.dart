// Widget + golden coverage for the reusable empty-state block.
// Regenerate goldens with: flutter test --update-goldens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/shared/empty_state_view.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('fr'),
  home: Scaffold(body: child),
);

void main() {
  group('EmptyStateView', () {
    testWidgets('renders message and no action by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyStateView(
            icon: Icons.inbox_outlined,
            message: 'Aucune fiche « Ménage »\npour le moment',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Ménage'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('shows action when provided and fires callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyStateView(
            icon: Icons.inbox_outlined,
            message: 'Aucune fiche « Cuisine »\npour le moment',
            actionLabel: 'Effacer les filtres',
            onAction: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Effacer les filtres'));
      expect(tapped, isTrue);
    });

    testWidgets('golden: task-specific empty state with action', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          EmptyStateView(
            icon: Icons.inbox_outlined,
            message: 'Aucune fiche « Ménage »\npour le moment',
            actionLabel: 'Effacer les filtres',
            onAction: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(EmptyStateView),
        matchesGoldenFile('goldens/empty_state_category.png'),
      );
    });
  });
}
