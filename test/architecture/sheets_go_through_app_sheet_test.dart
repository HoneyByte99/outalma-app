// Architecture guard: every modal bottom sheet goes through showAppSheet.
//
// showModalBottomSheet does not lift a sheet above the keyboard; the fix for
// that lives once, in lib/src/features/shared/app_sheet.dart. A hand-written
// sheet anywhere else would silently bring the defect back, so this test
// scans lib/ for the raw identifiers. Matching is by identifier, because 10
// of the 11 historical call sites were generic (`showModalBottomSheet<void>(`)
// and a `showModalBottomSheet(` pattern would have matched nothing.
//
// Runs from the package root, like test/l10n/arb_parity_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sheetHelper = 'lib/src/features/shared/app_sheet.dart';

/// Files allowed to use DraggableScrollableSheet directly. Each entry is a
/// sheet that has no text field, or one not converted yet: the list only
/// ever shrinks, a new entry needs a justification here.
const _draggableAllowlist = <String>{
  // Avatar grid, no text field: the keyboard never opens over it.
  'lib/src/features/profile/avatar_picker_sheet.dart',
};

final _rawSheetApi = RegExp(
  r'\b(showModalBottomSheet|showBottomSheet|ModalBottomSheetRoute)\b',
);
final _draggable = RegExp(r'\bDraggableScrollableSheet\b');
// Scaffold(bottomSheet:) is the third hand-written shape of a fixed footer
// that the keyboard would cover; nothing uses it today, keep it that way.
final _scaffoldBottomSheet = RegExp(r'\bbottomSheet\s*:');
// Keyboard handling lives in KeyboardAwareSheet. Plain substring, no trailing
// word boundary: `viewInsetsOf`, `.viewInsets.bottom` and `removeViewInsets`
// must all trip. A legitimate page-level use is added to this allowlist with
// its justification.
final _viewInsets = RegExp(r'viewInsets');
const _viewInsetsAllowlist = <String>{_sheetHelper};

// A sheet left non scroll-controlled is capped TWICE: the SDK at 9/16 of the
// screen, then KeyboardAwareSheet at what the keyboard leaves. On 375x667
// with a 291 px keyboard that is 84 px, far less than these sheets' own
// content, so a fixed Column overflows and paints its last rows under the
// keyboard. Such a builder must carry a scrollable.
final _isScrollControlled = RegExp(r'\bisScrollControlled\s*:');
final _column = RegExp(r'\bColumn\s*\(');
final _scrollable = RegExp(
  r'\b(SingleChildScrollView|ListView|GridView|CustomScrollView|Scrollable'
  r'|DraggableScrollableSheet|ReorderableListView|PageView|TabBarView)\b',
);

Iterable<File> _dartFilesUnderLib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/');

List<String> _offenders(RegExp pattern, {Set<String> except = const {}}) {
  final offenders = <String>[];
  for (final file in _dartFilesUnderLib()) {
    final path = _rel(file);
    if (except.contains(path)) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return offenders;
}

/// Only a generic argument may sit between the call's name and its opening
/// parenthesis: this rejects the mentions of `showAppSheet` in prose.
final _genericOrNothing = RegExp(r'^(<[^<>]*>)?$');

/// The balanced argument list of every `showAppSheet(...)` call in [source],
/// with the 1-based line of the call. String literals are skipped, so a
/// parenthesis inside a Dart string cannot unbalance the scan.
List<({int line, String args})> _showAppSheetCalls(String source) {
  const name = 'showAppSheet';
  final calls = <({int line, String args})>[];
  var from = 0;
  while (true) {
    final at = source.indexOf(name, from);
    if (at < 0) return calls;
    from = at + name.length;
    final open = source.indexOf('(', from);
    if (open < 0) return calls;
    if (!_genericOrNothing.hasMatch(source.substring(from, open))) continue;
    var depth = 0;
    String? quote;
    for (var i = open; i < source.length; i++) {
      final c = source[i];
      if (quote != null) {
        if (c == r'\') {
          i++;
        } else if (c == quote) {
          quote = null;
        }
        continue;
      }
      if (c == "'" || c == '"') {
        quote = c;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) {
          calls.add((
            line: source.substring(0, at).split('\n').length,
            args: source.substring(open + 1, i),
          ));
          from = i;
          break;
        }
      }
    }
  }
}

/// `path:line` of every non scroll-controlled sheet whose builder holds a
/// Column with nothing to scroll it. A builder that delegates to a widget
/// class holds no `Column(` of its own and is not judged here; the widget
/// tests cover that shape.
List<String> _unscrollableSheets(String path, String source) {
  final offenders = <String>[];
  for (final call in _showAppSheetCalls(source)) {
    if (_isScrollControlled.hasMatch(call.args)) continue;
    if (!_column.hasMatch(call.args)) continue;
    if (_scrollable.hasMatch(call.args)) continue;
    offenders.add('$path:${call.line}');
  }
  return offenders;
}

void main() {
  test('a modal sheet is opened with showAppSheet, never with the raw API', () {
    final offenders = _offenders(_rawSheetApi, except: {_sheetHelper});
    expect(
      offenders,
      isEmpty,
      reason:
          'une feuille modale passe par showAppSheet, voir app_sheet.dart :\n'
          '${offenders.join('\n')}',
    );
  });

  test('DraggableScrollableSheet only where the allowlist says so', () {
    final offenders = _offenders(_draggable, except: _draggableAllowlist);
    expect(
      offenders,
      isEmpty,
      reason:
          'DraggableScrollableSheet ignore le clavier : une feuille avec champ '
          'passe par showAppSheet (voir app_sheet.dart), une feuille sans champ '
          's ajoute a l allowlist de ce test avec sa justification :\n'
          '${offenders.join('\n')}',
    );
  });

  test('no Scaffold(bottomSheet:) footer anywhere', () {
    final offenders = _offenders(_scaffoldBottomSheet);
    expect(
      offenders,
      isEmpty,
      reason:
          'un pied de page fixe vit dans le body (Column[Expanded(...), '
          'footer]) pour rester au-dessus du clavier, pas dans '
          'Scaffold.bottomSheet :\n${offenders.join('\n')}',
    );
  });

  test('keyboard insets are handled in KeyboardAwareSheet only', () {
    final offenders = _offenders(_viewInsets, except: _viewInsetsAllowlist);
    expect(
      offenders,
      isEmpty,
      reason:
          'la gestion du clavier vit dans KeyboardAwareSheet (app_sheet.dart) ; '
          'un usage page-level legitime s ajoute a l allowlist de ce test avec '
          'sa justification :\n${offenders.join('\n')}',
    );
  });

  test('a non scroll-controlled sheet never holds a fixed Column', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnderLib()) {
      final path = _rel(file);
      if (path == _sheetHelper) continue;
      offenders.addAll(_unscrollableSheets(path, file.readAsStringSync()));
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'sans isScrollControlled, la feuille est bornee a (9/16 de l ecran) '
          'moins le clavier, soit 84 px sur un 375x667 : son contenu defile '
          '(SingleChildScrollView) au lieu de deborder, voir app_sheet.dart :\n'
          '${offenders.join('\n')}',
    );
  });

  // The scanner above is textual: these two fixtures keep it honest, so it can
  // never pass the suite by matching nothing.
  test('the non scroll-controlled scan sees a Column and forgives a scroll '
      'view', () {
    const fixed = '''
showAppSheet<void>(
  context: context,
  builder: (ctx) => Column(children: [Text('a (b')]),
);
''';
    expect(_unscrollableSheets('f.dart', fixed), ['f.dart:1']);

    const scrolls = '''
showAppSheet<void>(
  context: context,
  builder: (ctx) => SingleChildScrollView(child: Column(children: [])),
);
''';
    expect(_unscrollableSheets('f.dart', scrolls), isEmpty);

    const opted = '''
showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => Column(children: []),
);
''';
    expect(_unscrollableSheets('f.dart', opted), isEmpty);
  });

  test('the allowlist only names files that still exist', () {
    for (final path in _draggableAllowlist) {
      expect(File(path).existsSync(), isTrue, reason: '$path est parti');
    }
  });
}
