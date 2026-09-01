/// Diacritic folding for user-facing search.
///
/// On a phone keyboard in Senegal, typing without accents is the common case,
/// not the exception: "menage" must find "Ménage complet appartement". A plain
/// `toLowerCase()` does not, because the accented and unaccented letters are
/// different code points.
///
/// The table is deliberately explicit and additive rather than a general
/// Unicode normalisation: `dart:core` carries no NFD decomposition, pulling a
/// package in for a dozen letters would be the wrong trade, and this layer is
/// pure Dart by rule. Additive also means a string with no accent traverses the
/// function unchanged, which is what keeps the searches that already worked
/// working.
///
/// Fold BOTH sides of a comparison. Folding only the haystack leaves the mirror
/// case broken: an accented query against an unaccented value.
library;

/// Accented code point to its base letter, keyed by code UNIT rather than by
/// `String` so the fold needs no third-party grapheme package.
///
/// Lowercase only: [foldForSearch] lowercases first, and `toLowerCase()`
/// already maps `É` to `é`.
const Map<int, String> _folded = {
  0xE0: 'a', // à
  0xE1: 'a', // á
  0xE2: 'a', // â
  0xE3: 'a', // ã
  0xE4: 'a', // ä
  0xE5: 'a', // å
  0xE7: 'c', // ç
  0xE8: 'e', // è
  0xE9: 'e', // é
  0xEA: 'e', // ê
  0xEB: 'e', // ë
  0xEC: 'i', // ì
  0xED: 'i', // í
  0xEE: 'i', // î
  0xEF: 'i', // ï
  0xF1: 'n', // ñ
  0xF2: 'o', // ò
  0xF3: 'o', // ó
  0xF4: 'o', // ô
  0xF5: 'o', // õ
  0xF6: 'o', // ö
  0xF9: 'u', // ù
  0xFA: 'u', // ú
  0xFB: 'u', // û
  0xFC: 'u', // ü
  0xFD: 'y', // ý
  0xFF: 'y', // ÿ
  // Ligatures expand to two letters, so the result can be LONGER than the
  // input. Nothing downstream may assume the length is preserved.
  0x153: 'oe', // œ
  0xE6: 'ae', // æ
  0xDF: 'ss', // ß
};

/// Lowercases [input] and strips its diacritics, so a search is indifferent to
/// both case and accents.
///
/// Idempotent: folding an already folded string returns it unchanged.
String foldForSearch(String input) {
  final lower = input.toLowerCase();

  // Fast path. The overwhelming majority of strings are pure ASCII, and one
  // scan is cheaper than building a buffer for them.
  var hasNonAscii = false;
  for (var i = 0; i < lower.length; i++) {
    if (lower.codeUnitAt(i) > 0x7F) {
      hasNonAscii = true;
      break;
    }
  }
  if (!hasNonAscii) return lower;

  final out = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final unit = lower.codeUnitAt(i);
    final replacement = _folded[unit];
    if (replacement != null) {
      out.write(replacement);
    } else {
      // Anything unmapped passes through verbatim, surrogate halves included:
      // writing the code unit back preserves a surrogate pair across two
      // iterations, so an emoji or a non-Latin script survives intact.
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
