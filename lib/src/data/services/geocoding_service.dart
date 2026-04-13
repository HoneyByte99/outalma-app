import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Address suggestion from Places Autocomplete.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
  final String placeId;
  final String description;
}

/// Handles address autocomplete and geocoding via Google Places API (New).
///
/// Uses the new `places.googleapis.com/v1` endpoints which support CORS
/// for browser-side requests (unlike the legacy maps.googleapis.com endpoints).
class GeocodingService {
  GeocodingService({required String apiKey}) : _apiKey = apiKey;

  final String _apiKey;

  /// Returns autocomplete suggestions for the given [input].
  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return const [];

    final uri = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
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
        .where((s) => (s as Map)['placePrediction'] != null)
        .map((s) {
      final pred = s['placePrediction'] as Map<String, dynamic>;
      return PlaceSuggestion(
        placeId: pred['placeId'] as String,
        description:
            (pred['text'] as Map<String, dynamic>)['text'] as String,
      );
    }).toList();
  }

  /// Returns lat/lng for a given [placeId] via Place Details (New).
  Future<({double lat, double lng})?> getPlaceLatLng(String placeId) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId');

    final response = await http.get(
      uri,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'location',
      },
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
      return (results.first as Map<String, dynamic>)['formatted_address'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(apiKey: 'AIzaSyA8LD81VepWh8J31k6WqRH8FCJ85OLXBFA');
});
