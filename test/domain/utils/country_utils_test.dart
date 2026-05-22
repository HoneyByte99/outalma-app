import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/utils/country_utils.dart';

void main() {
  group('CountryUtils', () {
    group('flag()', () {
      test('returns correct flag for FR', () {
        expect(CountryUtils.flag('FR'), '🇫🇷');
      });

      test('returns correct flag for SN (Senegal)', () {
        expect(CountryUtils.flag('SN'), '🇸🇳');
      });

      test('accepts lowercase and normalises', () {
        expect(CountryUtils.flag('fr'), '🇫🇷');
        expect(CountryUtils.flag('sn'), '🇸🇳');
      });

      // flag() falls back only when the input length != 2 or contains non-alpha
      // chars. Any two-letter alpha string (e.g. 'XX') produces a regional
      // indicator pair — the fallback is not about whether the country exists.
      test('returns fallback globe for empty string', () {
        expect(CountryUtils.flag(''), '🌍');
      });

      test('returns fallback globe for single-letter code', () {
        expect(CountryUtils.flag('F'), '🌍');
      });

      test('returns fallback globe for three-letter code', () {
        expect(CountryUtils.flag('FRA'), '🌍');
      });

      test('returns fallback globe for numeric input', () {
        expect(CountryUtils.flag('12'), '🌍');
      });
    });

    group('name()', () {
      test('returns "France" for FR', () {
        expect(CountryUtils.name('FR'), 'France');
      });

      test('returns "Sénégal" for SN', () {
        expect(CountryUtils.name('SN'), 'Sénégal');
      });

      test('accepts lowercase and normalises', () {
        expect(CountryUtils.name('fr'), 'France');
      });

      test('falls back to uppercased code for unknown', () {
        expect(CountryUtils.name('XX'), 'XX');
        expect(CountryUtils.name('zz'), 'ZZ');
      });
    });

    group('flagAndName()', () {
      test('combines flag and name for FR', () {
        expect(CountryUtils.flagAndName('FR'), '🇫🇷 France');
      });

      test('combines flag and name for SN', () {
        expect(CountryUtils.flagAndName('SN'), '🇸🇳 Sénégal');
      });

      test('fallback name for unknown two-letter code', () {
        // flag('XX') produces a regional-indicator pair (not the globe) because
        // 'X' is a valid alpha char — only name() falls back to the uppercased code.
        expect(CountryUtils.flagAndName('XX'), '${CountryUtils.flag('XX')} XX');
      });
    });
  });
}
