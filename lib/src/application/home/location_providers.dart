import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active location filter for the home page service grid.
class LocationFilter {
  const LocationFilter({
    required this.label,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });
  final String label;
  final double lat;
  final double lng;
  final double radiusKm;

  LocationFilter copyWith({double? radiusKm}) => LocationFilter(
    label: label,
    lat: lat,
    lng: lng,
    radiusKm: radiusKm ?? this.radiusKm,
  );
}

final locationFilterProvider = StateProvider<LocationFilter?>((ref) => null);
