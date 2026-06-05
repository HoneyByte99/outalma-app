import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../app/app_theme.dart';

/// Identifies which legal document to display.
enum LegalDoc {
  terms('docs/legal/terms-of-use.md'),
  privacy('docs/legal/privacy-policy.md');

  const LegalDoc(this.assetPath);

  final String assetPath;

  static LegalDoc fromKey(String? key) =>
      key == 'privacy' ? LegalDoc.privacy : LegalDoc.terms;
}

/// In-app viewer for legal documents (CGU / privacy policy).
///
/// Loads the Markdown source from a bundled asset and renders it with a
/// lightweight renderer — no remote link, works fully offline.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.doc, required this.title});

  final LegalDoc doc;
  final String title;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: oc.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(doc.assetPath),
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
                      'Document indisponible.',
                      style: TextStyle(color: oc.secondaryText),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual cue at the top of the document (shield = privacy,
                // handshake = terms) — helps low-literacy users orient.
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
                _MarkdownView(source: snapshot.data!),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Minimal Markdown renderer covering the subset used in our legal docs:
/// headings (#, ##, ###), paragraphs, bullet/numbered lists, blockquotes (>),
/// horizontal rules (---), and inline bold (**...**).
class _MarkdownView extends StatelessWidget {
  const _MarkdownView({required this.source});

  final String source;

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

      if (trimmed == '---') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: oc.border, height: 1),
          ),
        );
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

      if (trimmed.startsWith('> ')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: oc.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: oc.primary, width: 3)),
            ),
            child: _richLine(
              trimmed.substring(2),
              theme.bodyMedium?.copyWith(color: oc.secondaryText, height: 1.5),
            ),
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
