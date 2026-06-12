// Contract test: the EN and FR ARB files must declare exactly the same
// translation keys. Outalma ships in France and Senegal — a key present in
// one locale only means a missing/broken string for every user of the other.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Set<String> keysOf(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>).keys
          .where((k) => !k.startsWith('@'))
          .toSet();

  test('app_en.arb and app_fr.arb declare the same keys', () {
    final en = keysOf('lib/l10n/app_en.arb');
    final fr = keysOf('lib/l10n/app_fr.arb');

    expect(
      fr.difference(en),
      isEmpty,
      reason: 'Keys present only in app_fr.arb — add them to app_en.arb.',
    );
    expect(
      en.difference(fr),
      isEmpty,
      reason: 'Keys present only in app_en.arb — add them to app_fr.arb.',
    );
  });
}
