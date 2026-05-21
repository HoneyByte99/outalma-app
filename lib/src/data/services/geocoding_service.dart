import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Address suggestion from Places Autocomplete.
class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

/// Handles address autocomplete and geocoding via Google Places API (New).
///
/// Uses the new `places.googleapis.com/v1` endpoints which support CORS
/// for browser-side requests (unlike the legacy maps.googleapis.com endpoints).
class GeocodingService {
  GeocodingService({required String apiKey}) : _apiKey = apiKey {
    assert(
      _apiKey.isNotEmpty,
      'MAPS_API_KEY manquante — lance avec --dart-define=MAPS_API_KEY=... (cf. scripts/run.sh)',
    );
  }

  final String _apiKey;

  /// Returns autocomplete suggestions for the given [input].
  /// Tries Google Places API first; falls back to Nominatim if unavailable.
  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return const [];

    if (_apiKey.isNotEmpty) {
      try {
        final results = await _googleAutocomplete(input);
        if (results.isNotEmpty) return results;
      } catch (_) {
        // fall through to Nominatim
      }
    }

    return _nominatimSearch(input);
  }

  Future<List<PlaceSuggestion>> _googleAutocomplete(String input) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:autocomplete',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': _apiKey},
      body: jsonEncode({
        'input': input,
        'languageCode': 'fr',
        'includedRegionCodes': ['fr', 'sn'],
      }),
    );

    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = json['suggestions'] as List? ?? [];

    return suggestions
        .cast<Map<String, dynamic>>()
        .where((s) => s['placePrediction'] != null)
        .map((s) {
          final pred = s['placePrediction'] as Map<String, dynamic>;
          return PlaceSuggestion(
            placeId: pred['placeId'] as String,
            description:
                (pred['text'] as Map<String, dynamic>)['text'] as String,
          );
        })
        .toList();
  }

  /// Nominatim (OpenStreetMap) free geocoding — encodes lat/lng in the placeId
  /// as "nominatim:<lat>,<lng>" so no second lookup is needed.
  Future<List<PlaceSuggestion>> _nominatimSearch(String input) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {
          'q': input,
          'format': 'json',
          'limit': '5',
          'accept-language': 'fr',
          'countrycodes': 'fr,sn',
        },
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Outalma/1.0'},
      );

      if (response.statusCode != 200) return const [];

      final results = jsonDecode(response.body) as List;
      return results
          .cast<Map<String, dynamic>>()
          .map((r) {
            final lat = r['lat'] as String;
            final lng = r['lon'] as String;
            final name = (r['display_name'] as String)
                .split(',')
                .take(3)
                .join(',')
                .trim();
            return PlaceSuggestion(
              placeId: 'nominatim:$lat,$lng',
              description: name,
            );
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns lat/lng for a given [placeId].
  /// Nominatim placeIds are encoded as "nominatim:<lat>,<lng>".
  Future<({double lat, double lng})?> getPlaceLatLng(String placeId) async {
    if (placeId.startsWith('nominatim:')) {
      final coords = placeId.substring('nominatim:'.length).split(',');
      if (coords.length == 2) {
        final lat = double.tryParse(coords[0]);
        final lng = double.tryParse(coords[1]);
        if (lat != null && lng != null) return (lat: lat, lng: lng);
      }
      return null;
    }

    final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId');

    final response = await http.get(
      uri,
      headers: {'X-Goog-Api-Key': _apiKey, 'X-Goog-FieldMask': 'location'},
    );

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final location = json['location'] as Map<String, dynamic>?;
    if (location == null) return null;

    return (
      lat: (location['latitude'] as num).toDouble(),
      lng: (location['longitude'] as num).toDouble(),
    );
  }

  /// Reverse-geocodes [lat]/[lng] into a human-readable address label.
  /// Returns `null` on failure.
  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng&language=fr&key=$_apiKey',
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return (results.first as Map<String, dynamic>)['formatted_address']
          as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Injected at build time via `--dart-define=MAPS_API_KEY=<key>`.
/// Unified key name across Dart, iOS (Secrets.xcconfig) and Android.
/// In dev: use scripts/run.sh. In CI: inject via the MAPS_API_KEY GitHub Secret.
const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(apiKey: _mapsApiKey);
});
