// Unit tests for the client-side Senegal-only location gate (CADRAGE section 5).
// This mirrors the server's assertServiceLocationInSenegal; the cases below
// track the server tests one-for-one (foreign country, foreign coordinates,
// SN-labelled foreign coordinates, Dakar, and a no-signal address).
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/services/senegal_location.dart';

void main() {
  group('isWithinSenegalBox', () {
    test('Dakar is inside', () {
      expect(isWithinSenegalBox(14.6928, -17.4467), isTrue);
    });

    test('Paris is outside', () {
      expect(isWithinSenegalBox(48.8566, 2.3522), isFalse);
    });

    test('box edges', () {
      expect(isWithinSenegalBox(12.0, -17.9), isTrue);
      expect(isWithinSenegalBox(17.0, -11.0), isTrue);
      expect(isWithinSenegalBox(11.9, -15.0), isFalse);
      expect(isWithinSenegalBox(15.0, -10.9), isFalse);
    });
  });

  group('evaluateSenegalLocation', () {
    test('foreign countryCode is outside', () {
      expect(
        evaluateSenegalLocation(countryCode: 'FR'),
        SenegalLocationResult.outside,
      );
    });

    test('foreign coordinates are outside', () {
      expect(
        evaluateSenegalLocation(lat: 48.8566, lng: 2.3522),
        SenegalLocationResult.outside,
      );
    });

    test('SN-labelled foreign coordinates are outside (spoof)', () {
      expect(
        evaluateSenegalLocation(countryCode: 'SN', lat: 48.8566, lng: 2.3522),
        SenegalLocationResult.outside,
      );
    });

    test('Dakar with SN countryCode is ok (case-insensitive)', () {
      expect(
        evaluateSenegalLocation(countryCode: 'sn', lat: 14.6928, lng: -17.4467),
        SenegalLocationResult.ok,
      );
    });

    test('no signal at all is ok (allowed, server has final say)', () {
      expect(evaluateSenegalLocation(), SenegalLocationResult.ok);
    });

    test('empty countryCode is treated as no signal', () {
      expect(
        evaluateSenegalLocation(countryCode: '   '),
        SenegalLocationResult.ok,
      );
    });
  });
}
