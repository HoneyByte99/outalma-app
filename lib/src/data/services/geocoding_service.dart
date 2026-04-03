import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Geocodes an address string to lat/lng using the Google Geocoding API.
class GeocodingService {
  GeocodingService({required String apiKey}) : _apiKey = apiKey;

  final String _apiKey;

  /// Returns `(lat, lng)` for the given [address], or `null` if not found.
  Future<({double lat, double lng})?> geocode(String address) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': address,
      'key': _apiKey,
      'language': 'fr',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List?;
    if (results == null || results.isEmpty) return null;

    final location =
        results[0]['geometry']['location'] as Map<String, dynamic>;
    return (
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
    );
  }
}

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(apiKey: 'AIzaSyBm5tfNJApgvDpEjPSqDJMeVr2lIo1q-d8');
});
