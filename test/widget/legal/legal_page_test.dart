// Widget coverage for LegalPage's homemade Markdown renderer and, since the
// legal-page-i18n increment, for the language-aware asset selection: which
// variant gets loaded for the current locale, the French fallback when no
// variant exists, and the visible notice that must accompany that fallback.
//
// The renderer is intentionally minimal (no package dependency), which means
// every syntax character it does not understand risks leaking through raw
// (an unrendered "> ", "---" or "_") straight into the user-visible text.
// The first group renders the real bundled CGU / privacy policy assets and
// asserts none of that raw syntax survives. The later groups inject a fake
// asset loader via LegalPage's `@visibleForTesting loadString` so the
// language-selection logic can be exercised without touching real assets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/legal/legal_page.dart';

Widget _wrap(
  LegalDoc doc, {
  Locale locale = const Locale('fr'),
  Future<String> Function(String key)? loadString,
}) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  home: LegalPage(doc: doc, title: 'Test', loadString: loadString),
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

  group('loadLegalDoc (pure asset-selection logic)', () {
    test('loads the localized variant when it exists', () async {
      final result = await loadLegalDoc(
        LegalDoc.terms,
        'en',
        loadString: (key) async {
          expect(key, 'docs/legal/terms-of-use.en.md');
          return 'EN CONTENT';
        },
      );

      expect(result.text, 'EN CONTENT');
      expect(result.isFallback, isFalse);
    });

    test(
      'falls back to the French canonical when the variant is missing',
      () async {
        final requested = <String>[];
        final result = await loadLegalDoc(
          LegalDoc.terms,
          'en',
          loadString: (key) async {
            requested.add(key);
            if (key == 'docs/legal/terms-of-use.en.md') {
              throw Exception('asset not found');
            }
            return 'FR CONTENT';
          },
        );

        expect(result.text, 'FR CONTENT');
        expect(result.isFallback, isTrue);
        expect(requested, [
          'docs/legal/terms-of-use.en.md',
          'docs/legal/terms-of-use.md',
        ]);
      },
    );

    test('the French UI never triggers a fallback', () async {
      final requested = <String>[];
      final result = await loadLegalDoc(
        LegalDoc.terms,
        'fr',
        loadString: (key) async {
          requested.add(key);
          return 'FR CONTENT';
        },
      );

      expect(result.text, 'FR CONTENT');
      expect(result.isFallback, isFalse);
      expect(requested, ['docs/legal/terms-of-use.md']);
    });
  });

  group('LegalPage surfaces the language selection end-to-end', () {
    testWidgets('English locale loads the English variant, no notice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LegalDoc.terms,
          locale: const Locale('en'),
          loadString: (key) async {
            if (key == 'docs/legal/terms-of-use.en.md') {
              return '# Terms\n\nLast updated: 1 January 2026\n\nEnglish variant body.';
            }
            throw Exception('unexpected asset request: $key');
          },
        ),
      );
      await tester.pumpAndSettle();

      final text = _visibleText(tester);
      expect(text, contains('English variant body.'));
      expect(text, isNot(contains("isn't available in your language yet")));
    });

    testWidgets(
      'missing English variant serves French AND shows the visible fallback notice',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            LegalDoc.terms,
            locale: const Locale('en'),
            loadString: (key) async {
              if (key == 'docs/legal/terms-of-use.en.md') {
                throw Exception('asset not found');
              }
              return '# Conditions\n\nDernière mise à jour : 5 juin 2026\n\nCorps en français.';
            },
          ),
        );
        await tester.pumpAndSettle();

        final text = _visibleText(tester);
        // The document itself is served in French (the fallback content)...
        expect(text, contains('Corps en français.'));
        // ...but the UI notice is localized to the current (English) locale,
        // and explicitly says so.
        expect(text, contains("isn't available in your language yet"));
      },
    );

    testWidgets(
      'the "last updated" date line is recognised in French and in English',
      (tester) async {
        const frDateLine = 'Dernière mise à jour : 5 juin 2026';
        await tester.pumpWidget(
          _wrap(
            LegalDoc.terms,
            locale: const Locale('fr'),
            loadString: (_) async => '# Titre\n\n$frDateLine\n\nCorps.',
          ),
        );
        await tester.pumpAndSettle();

        // Recognised lines render through the plain (non-rich) Text branch,
        // in italic: an unrecognised prefix would instead fall through to
        // the rich-paragraph branch (Text.rich), which `find.text` (without
        // findRichText: true) would not match at all.
        final frText = tester.widget<Text>(find.text(frDateLine));
        expect(frText.style?.fontStyle, FontStyle.italic);

        const enDateLine = 'Last updated: 1 January 2026';
        await tester.pumpWidget(
          _wrap(
            LegalDoc.terms,
            locale: const Locale('en'),
            loadString: (key) async {
              if (key == 'docs/legal/terms-of-use.en.md') {
                return '# Title\n\n$enDateLine\n\nBody.';
              }
              throw Exception('unexpected asset request: $key');
            },
          ),
        );
        await tester.pumpAndSettle();

        final enText = tester.widget<Text>(find.text(enDateLine));
        expect(enText.style?.fontStyle, FontStyle.italic);
      },
    );
  });
}
