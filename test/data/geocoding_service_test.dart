// Tests for GeocodingService.
//
// Covered:
//   - autocomplete(): empty / short input returns [] without HTTP
//   - autocomplete(): empty API key falls back to Nominatim
//   - autocomplete(): valid API key calls Google Places first
//   - getPlaceLatLng(): nominatim-encoded placeId parses without HTTP
//   - getPlaceLatLng(): bad nominatim data returns null
//   - reverseGeocode(): HTTP 200 returns formatted_address
//   - reverseGeocode(): HTTP error returns null

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:outalma_app/src/data/services/geocoding_service.dart';

// ---------------------------------------------------------------------------
// Fake response helpers
// ---------------------------------------------------------------------------

http.Response _nominatimResponse() {
  final body = jsonEncode([
    {
      'lat': '48.8566',
      'lon': '2.3522',
      'display_name': 'Paris, Île-de-France, France',
    },
  ]);
  return http.Response(body, 200);
}

http.Response _googlePlacesResponse() {
  final body = jsonEncode({
    'suggestions': [
      {
        'placePrediction': {
          'placeId': 'ChIJD7fiBh9u5kcRYJSMaMOCCwQ',
          'text': {'text': 'Paris, France'},
        },
      },
    ],
  });
  return http.Response(body, 200);
}

http.Response _reverseGeocodeResponse() {
  final body = jsonEncode({
    'results': [
      {'formatted_address': '75001 Paris, France'},
    ],
  });
  return http.Response(body, 200);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GeocodingService.autocomplete', () {
    test('returns empty list for empty input without HTTP', () async {
      // No client injected — any real HTTP call would throw.
      final service = GeocodingService(apiKey: 'key');
      final result = await service.autocomplete('');
      expect(result, isEmpty);
    });

    test('returns empty list for single-char input without HTTP', () async {
      final service = GeocodingService(apiKey: 'key');
      final result = await service.autocomplete('P');
      expect(result, isEmpty);
    });

    test('empty API key falls back to Nominatim', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        return _nominatimResponse();
      });

      final service = GeocodingService(apiKey: '', httpClient: client);
      final results = await service.autocomplete('Paris');

      expect(results, hasLength(1));
      expect(results.first.description, contains('Paris'));
      expect(results.first.placeId, startsWith('nominatim:'));
    });

    test('valid API key calls Google Places first', () async {
      var googleCalled = false;
      final client = MockClient((request) async {
        if (request.url.host == 'places.googleapis.com') {
          googleCalled = true;
          return _googlePlacesResponse();
        }
        fail('Unexpected request to ${request.url}');
      });

      final service = GeocodingService(apiKey: 'valid-key', httpClient: client);
      final results = await service.autocomplete('Paris');

      expect(googleCalled, isTrue);
      expect(results, hasLength(1));
      expect(results.first.placeId, 'ChIJD7fiBh9u5kcRYJSMaMOCCwQ');
    });

    test(
      'falls back to Nominatim when Google returns empty suggestions',
      () async {
        var nominatimCalled = false;
        final client = MockClient((request) async {
          if (request.url.host == 'places.googleapis.com') {
            return http.Response(jsonEncode({'suggestions': []}), 200);
          }
          if (request.url.host == 'nominatim.openstreetmap.org') {
            nominatimCalled = true;
            return _nominatimResponse();
          }
          fail('Unexpected request to ${request.url}');
        });

        final service = GeocodingService(
          apiKey: 'valid-key',
          httpClient: client,
        );
        final results = await service.autocomplete('Paris');

        expect(nominatimCalled, isTrue);
        expect(results, isNotEmpty);
      },
    );
  });

  group('GeocodingService.getPlaceLatLng', () {
    test('parses nominatim-encoded placeId without HTTP', () async {
      final service = GeocodingService(apiKey: '');
      final coords = await service.getPlaceLatLng('nominatim:48.8566,2.3522');

      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(48.8566, 0.0001));
      expect(coords.lng, closeTo(2.3522, 0.0001));
    });

    test('returns null for malformed nominatim data', () async {
      final service = GeocodingService(apiKey: '');
      final result = await service.getPlaceLatLng('nominatim:bad,data');
      expect(result, isNull);
    });

    test('returns null for nominatim prefix with missing lng', () async {
      final service = GeocodingService(apiKey: '');
      final result = await service.getPlaceLatLng('nominatim:48.8566');
      expect(result, isNull);
    });
  });

  group('GeocodingService.reverseGeocode', () {
    test('returns formatted_address on HTTP 200', () async {
      final client = MockClient((_) async => _reverseGeocodeResponse());
      final service = GeocodingService(apiKey: 'key', httpClient: client);

      final address = await service.reverseGeocode(48.8566, 2.3522);
      expect(address, '75001 Paris, France');
    });

    test('returns null on HTTP error', () async {
      final client = MockClient((_) async => http.Response('', 500));
      final service = GeocodingService(apiKey: 'key', httpClient: client);

      final address = await service.reverseGeocode(48.8566, 2.3522);
      expect(address, isNull);
    });

    test('returns null when results list is empty', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'results': []}), 200),
      );
      final service = GeocodingService(apiKey: 'key', httpClient: client);

      final address = await service.reverseGeocode(48.8566, 2.3522);
      expect(address, isNull);
    });
  });
}
