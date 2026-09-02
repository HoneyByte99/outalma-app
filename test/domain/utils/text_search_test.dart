import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/utils/text_search.dart';

/// The point of this fold is a phone keyboard in Senegal, where typing without
/// accents is the common case. Every claim the doc comment makes is asserted
/// here, including the two that are easy to break later: an unaccented string
/// must traverse unchanged, and the fold must be idempotent.
void main() {
  group('foldForSearch', () {
    test('it lowercases', () {
      expect(foldForSearch('MENAGE'), 'menage');
    });

    test('it strips French accents', () {
      expect(foldForSearch('Ménage'), 'menage');
      expect(foldForSearch('Sénégal'), 'senegal');
      expect(foldForSearch('à â ä'), 'a a a');
      expect(foldForSearch('è é ê ë'), 'e e e e');
      expect(foldForSearch('î ï'), 'i i');
      expect(foldForSearch('ô ö'), 'o o');
      expect(foldForSearch('ù û ü'), 'u u u');
      expect(foldForSearch('ç'), 'c');
      expect(foldForSearch('ÿ'), 'y');
      expect(foldForSearch('ñ'), 'n');
    });

    test('it strips accents from UPPERCASE letters too', () {
      // toLowerCase runs first, so É must reach the table as é. Getting the
      // order wrong here leaves every capitalised title unmatched.
      expect(foldForSearch('ÉLECTRICITÉ'), 'electricite');
      expect(foldForSearch('SÉNÉGAL'), 'senegal');
      expect(foldForSearch('Ça'), 'ca');
    });

    test('ligatures expand, so the result can be longer than the input', () {
      expect(foldForSearch('œuvre'), 'oeuvre');
      expect(foldForSearch('Œuvre'), 'oeuvre');
      expect(foldForSearch('æther'), 'aether');
      expect(foldForSearch('Straße'), 'strasse');
      expect(foldForSearch('œ').length, greaterThan('œ'.length));
    });

    test('a string with no accent traverses unchanged', () {
      // This is what keeps the searches that already worked working.
      expect(
        foldForSearch('menage complet appartement'),
        'menage complet appartement',
      );
      expect(foldForSearch('plomberie 24/7'), 'plomberie 24/7');
      expect(foldForSearch('+221'), '+221');
    });

    test('it is idempotent', () {
      const inputs = ['Ménage', 'ÉLECTRICITÉ', 'œuvre', 'Straße', 'plomberie'];
      for (final input in inputs) {
        final once = foldForSearch(input);
        expect(foldForSearch(once), once, reason: 'folding $input twice');
      }
    });

    test('the empty string folds to itself', () {
      expect(foldForSearch(''), '');
    });

    test('unmapped non-ASCII survives intact, surrogate pairs included', () {
      // The fold walks code UNITS, so an emoji is two of them. Writing each one
      // back is what keeps the pair together.
      expect(foldForSearch('ménage 🧹'), 'menage 🧹');
      expect(foldForSearch('العربية'), 'العربية');
    });
  });
}
