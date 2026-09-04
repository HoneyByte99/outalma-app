import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';

/// Identifies which legal document to display.
enum LegalDoc {
  terms('terms-of-use'),
  privacy('privacy-policy');

  const LegalDoc(this._slug);

  /// Base file name (without extension) shared by every language variant.
  final String _slug;

  /// Language the canonical, always-present file is written in. Every other
  /// language is an optional variant that falls back to this one when
  /// missing.
  static const _fallbackLanguageCode = 'fr';

  /// Asset path for [languageCode], following the `<slug>.<lang>.md`
  /// convention (e.g. `terms-of-use.en.md`). The canonical language has no
  /// suffix (`terms-of-use.md`).
  String _assetPathFor(String languageCode) =>
      languageCode == _fallbackLanguageCode
      ? _fallbackAssetPath
      : 'docs/legal/$_slug.$languageCode.md';

  String get _fallbackAssetPath => 'docs/legal/$_slug.md';

  static LegalDoc fromKey(String? key) =>
      key == 'privacy' ? LegalDoc.privacy : LegalDoc.terms;
}

/// Result of loading a legal document: its Markdown source plus whether the
/// requested language variant was missing and this is the French fallback.
typedef LegalDocResult = ({String text, bool isFallback});

/// Loads [doc]'s Markdown for [languageCode].
///
/// If no variant exists for that language, silently falls back to the
/// French canonical file and reports it via [LegalDocResult.isFallback] so
/// the caller can surface a visible notice (a document in the wrong
/// language beats no document at all, but the substitution must not be
/// invisible).
@visibleForTesting
Future<LegalDocResult> loadLegalDoc(
  LegalDoc doc,
  String languageCode, {
  Future<String> Function(String key)? loadString,
}) async {
  final load = loadString ?? rootBundle.loadString;
  final isCanonical = languageCode == LegalDoc._fallbackLanguageCode;
  if (!isCanonical) {
    try {
      final text = await load(doc._assetPathFor(languageCode));
      return (text: text, isFallback: false);
    } catch (_) {
      // No localized variant for this language: fall through to French.
    }
  }
  final text = await load(doc._fallbackAssetPath);
  return (text: text, isFallback: !isCanonical);
}

/// In-app viewer for legal documents (CGU / privacy policy).
///
/// Loads the Markdown source from a bundled asset and renders it with a
/// lightweight renderer (no remote link, works fully offline).
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.doc,
    required this.title,
    @visibleForTesting this.loadString,
  });

  final LegalDoc doc;
  final String title;

  /// Overrides the asset loader used by [loadLegalDoc]; only ever set by
  /// tests to simulate a missing language variant without touching the
  /// real bundled assets.
  @visibleForTesting
  final Future<String> Function(String key)? loadString;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: oc.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<LegalDocResult>(
        future: loadLegalDoc(doc, languageCode, loadString: loadString),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: oc.primary));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: oc.secondaryText,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.legalDocUnavailable,
                      style: TextStyle(color: oc.secondaryText),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(l10n.back),
                    ),
                  ],
                ),
              ),
            );
          }
          final result = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual cue at the top of the document (shield = privacy,
                // handshake = terms), helps low-literacy users orient.
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: oc.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      doc == LegalDoc.privacy
                          ? Icons.shield_outlined
                          : Icons.handshake_outlined,
                      color: oc.primary,
                      size: 32,
                    ),
                  ),
                ),
                if (result.isFallback)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: oc.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: oc.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.legalFallbackNotice,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: oc.primaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _MarkdownView(
                  source: result.text,
                  lastUpdatedPrefixes: _lastUpdatedPrefixes,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The "last updated" line prefix in every supported language, so the
  /// date line is recognised regardless of which language variant actually
  /// got loaded (the requested one, or the French fallback).
  static final List<String> _lastUpdatedPrefixes = AppLocalizations
      .supportedLocales
      .map((locale) => lookupAppLocalizations(locale).legalLastUpdatedPrefix)
      .toList();
}

/// Minimal Markdown renderer covering the subset used in our legal docs:
/// headings (#, ##, ###), paragraphs, bullet/numbered lists, the "last
/// updated" date line, and inline bold (**...**).
class _MarkdownView extends StatelessWidget {
  const _MarkdownView({
    required this.source,
    required this.lastUpdatedPrefixes,
  });

  final String source;

  /// Every known localized prefix of the "last updated" line (see
  /// [LegalPage._lastUpdatedPrefixes]).
  final List<String> lastUpdatedPrefixes;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final theme = Theme.of(context).textTheme;
    final lines = source.split('\n');
    final widgets = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          _block(
            text: trimmed.substring(4),
            style: theme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: oc.primaryText,
            ),
            top: 10,
          ),
        );
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(
          _block(
            text: trimmed.substring(3),
            style: theme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: oc.primaryText,
            ),
            top: 16,
          ),
        );
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(
          _block(
            text: trimmed.substring(2),
            style: theme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: oc.primaryText,
            ),
            top: 4,
          ),
        );
        continue;
      }

      if (lastUpdatedPrefixes.any(trimmed.startsWith)) {
        widgets.add(
          _block(
            text: trimmed,
            style: theme.bodySmall?.copyWith(
              color: oc.secondaryText,
              fontStyle: FontStyle.italic,
            ),
            top: 2,
          ),
        );
        continue;
      }

      // Bullet list item.
      if (trimmed.startsWith('- ')) {
        widgets.add(
          _listItem(context, marker: '•', text: trimmed.substring(2)),
        );
        continue;
      }

      // Numbered list item (e.g. "1. ...").
      final numbered = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(trimmed);
      if (numbered != null) {
        widgets.add(
          _listItem(
            context,
            marker: '${numbered.group(1)}.',
            text: numbered.group(2)!,
          ),
        );
        continue;
      }

      // Plain paragraph.
      widgets.add(
        _block(
          text: trimmed,
          style: theme.bodyMedium?.copyWith(
            color: oc.primaryText,
            height: 1.55,
          ),
          top: 2,
          rich: true,
          context: context,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _block({
    required String text,
    required TextStyle? style,
    double top = 0,
    bool rich = false,
    BuildContext? context,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 2),
      child: rich ? _richLine(text, style) : Text(text, style: style),
    );
  }

  Widget _listItem(
    BuildContext context, {
    required String marker,
    required String text,
  }) {
    final oc = context.oc;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: oc.primaryText, height: 1.5);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(marker, style: style?.copyWith(color: oc.primary)),
          ),
          Expanded(child: _richLine(text, style)),
        ],
      ),
    );
  }

  /// Renders inline **bold** spans within a single line.
  Widget _richLine(String text, TextStyle? base) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
