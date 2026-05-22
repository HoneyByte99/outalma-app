// Widget tests for VerifiedBadge.
//
// VerifiedBadge has a single `compact` boolean that controls layout:
//   - compact: false (default) — pill container with icon + text label
//   - compact: true            — icon-only wrapped in a Tooltip
//
// There is no "unverified" state — the widget is only rendered when the
// profile is verified; callers simply omit it otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/shared/verified_badge.dart';
import 'package:outalma_app/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('VerifiedBadge — full (compact: false)', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge()));
      await tester.pump();
      expect(find.byType(VerifiedBadge), findsOneWidget);
    });

    testWidgets('shows the verified_rounded icon', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge()));
      await tester.pump();
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('shows the "Verified" text label', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge()));
      await tester.pump();
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('is a Container (pill), not a bare Tooltip', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge()));
      await tester.pump();
      // In full mode the root widget is a Container; no Tooltip at widget level.
      expect(find.byType(Tooltip), findsNothing);
    });
  });

  group('VerifiedBadge — compact (compact: true)', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge(compact: true)));
      await tester.pump();
      expect(find.byType(VerifiedBadge), findsOneWidget);
    });

    testWidgets('shows the verified_rounded icon', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge(compact: true)));
      await tester.pump();
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('does NOT show the text label', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge(compact: true)));
      await tester.pump();
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('wraps icon in a Tooltip with verified label', (tester) async {
      await tester.pumpWidget(_wrap(const VerifiedBadge(compact: true)));
      await tester.pump();
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Verified');
    });
  });

  group('VerifiedBadge — layout difference between modes', () {
    testWidgets('full mode renders text while compact mode does not',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Row(
              children: [
                VerifiedBadge(),
                VerifiedBadge(compact: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // There are two badges but only the full one emits a Text widget.
      expect(find.text('Verified'), findsOneWidget);
      // Both show the icon.
      expect(find.byIcon(Icons.verified_rounded), findsNWidgets(2));
    });
  });
}
