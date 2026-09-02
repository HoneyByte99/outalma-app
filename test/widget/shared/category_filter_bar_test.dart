// Widget + golden coverage for the client task filter bar.
//
// The golden snapshots let a human SEE the rendered chips (selected vs not) and
// the icon glyphs. Regenerate with: flutter test --update-goldens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/features/shared/category_filter_bar.dart';
import '../../support/golden_authority.dart';

Widget _wrap({
  required CategoryId? selected,
  required ValueChanged<CategoryId?> onSelected,
}) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('fr'),
  home: Scaffold(
    body: Center(
      child: CategoryFilterBar(selected: selected, onSelected: onSelected),
    ),
  ),
);

void main() {
  group('CategoryFilterBar', () {
    testWidgets('shows "Tout" plus the 4 curated MVP tasks in order', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(selected: null, onSelected: (_) {}));
      await tester.pumpAndSettle();

      // 5 chips total.
      expect(find.byType(CategoryFilterChip), findsNWidgets(5));

      // Curated order: Tout, Menage, Repassage, Cuisine, Garde d'enfants.
      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('Ménage'), findsOneWidget);
      expect(find.text('Repassage'), findsOneWidget);
      expect(find.text('Cuisine'), findsOneWidget);
      expect(find.text("Garde d'enfants"), findsOneWidget);

      final dxTout = tester.getCenter(find.text('Tout')).dx;
      final dxMenage = tester.getCenter(find.text('Ménage')).dx;
      final dxRepassage = tester.getCenter(find.text('Repassage')).dx;
      final dxCuisine = tester.getCenter(find.text('Cuisine')).dx;
      final dxGarde = tester.getCenter(find.text("Garde d'enfants")).dx;
      expect(dxTout < dxMenage, isTrue);
      expect(dxMenage < dxRepassage, isTrue);
      expect(dxRepassage < dxCuisine, isTrue);
      expect(dxCuisine < dxGarde, isTrue);
    });

    testWidgets('hidden (non-MVP) categories are absent', (tester) async {
      await tester.pumpWidget(_wrap(selected: null, onSelected: (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Plomberie'), findsNothing);
      expect(find.text('Jardinage'), findsNothing);
    });

    testWidgets('tapping a chip reports the matching CategoryId', (
      tester,
    ) async {
      CategoryId? tapped;
      var called = false;
      await tester.pumpWidget(
        _wrap(
          selected: null,
          onSelected: (v) {
            tapped = v;
            called = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cuisine'));
      expect(called, isTrue);
      expect(tapped, CategoryId.cuisine);
    });

    testWidgets('active chip exposes button + selected semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(selected: CategoryId.menage, onSelected: (_) {}),
      );
      await tester.pumpAndSettle();
      // Closest Semantics ancestor of the label is the chip's own node.
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(of: find.text('Ménage'), matching: find.byType(Semantics))
            .first,
      );
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.selected, isTrue);
      expect(semantics.properties.label, 'Ménage');
    });

    testWidgets('golden: "Tout" selected (default)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 72));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(selected: null, onSelected: (_) {}));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CategoryFilterBar),
        matchesGoldenFile('goldens/category_filter_bar_all.png'),
      );
    }, skip: goldenSkip);

    testWidgets('golden: "Menage" selected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 72));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(selected: CategoryId.menage, onSelected: (_) {}),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CategoryFilterBar),
        matchesGoldenFile('goldens/category_filter_bar_menage.png'),
      );
    }, skip: goldenSkip);
  });
}
