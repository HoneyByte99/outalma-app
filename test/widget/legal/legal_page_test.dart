// Widget coverage for LegalPage's homemade Markdown renderer.
//
// The renderer is intentionally minimal (no package dependency), which means
// every syntax character it does not understand risks leaking through raw
// (an unrendered "> ", "---" or "_") straight into the user-visible text.
// These tests render the real bundled CGU / privacy policy assets and assert
// none of that raw syntax survives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/legal/legal_page.dart';

Widget _wrap(LegalDoc doc) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('fr'),
  home: LegalPage(doc: doc, title: 'Test'),
);

/// Collects every visible Text/Text.rich string under the widget tree.
String _visibleText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    if (widget.data != null) buffer.writeln(widget.data);
    final span = widget.textSpan;
    if (span != null) buffer.writeln(span.toPlainText());
  }
  return buffer.toString();
}

// Checks the renderer left none of the three raw syntax markers this brief
// asked to remove: the blockquote marker ("> "), a standalone horizontal
// rule line ("---" alone on a line), and an italic-underscore-wrapped date
// line ("_..._"). Deliberately narrower than "no dash/underscore anywhere",
// because the source docs also contain Markdown tables ("|---|---|") that
// this homemade renderer never supported in the first place: a pre-existing
// gap outside this brief's scope, flagged in the report instead of masked
// here.
void _expectNoResidualLegalSyntax(String text) {
  expect(text, isNot(contains('> ')));
  expect(text.split('\n').map((l) => l.trim()), isNot(contains('---')));
  expect(text, isNot(matches(RegExp(r'_[^_\n]+_'))));
}

void main() {
  group('LegalPage renders clean text (no residual Markdown syntax)', () {
    testWidgets('terms-of-use document', (tester) async {
      await tester.pumpWidget(_wrap(LegalDoc.terms));
      await tester.pumpAndSettle();

      final text = _visibleText(tester);
      _expectNoResidualLegalSyntax(text);

      // The former blockquote content still renders, as a normal paragraph.
      expect(text, contains('Version de test.'));
      expect(text, contains('Dernière mise à jour'));
    });

    testWidgets('privacy-policy document', (tester) async {
      await tester.pumpWidget(_wrap(LegalDoc.privacy));
      await tester.pumpAndSettle();

      final text = _visibleText(tester);
      _expectNoResidualLegalSyntax(text);

      expect(text, contains('jamais affiché publiquement'));
      expect(text, contains('Dernière mise à jour'));
    });
  });
}
