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

  test('the allowlist only names files that still exist', () {
    for (final path in _draggableAllowlist) {
      expect(File(path).existsSync(), isTrue, reason: '$path est parti');
    }
  });
}
