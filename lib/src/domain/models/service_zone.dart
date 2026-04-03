class ServiceZone {
  const ServiceZone({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  /// Display label — what the user typed ("Paris 11e", "Lyon").
  final String label;

  final double latitude;
  final double longitude;

  /// Intervention radius in whole kilometers (1–200).
  final int radiusKm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceZone &&
          label == other.label &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          radiusKm == other.radiusKm;

  @override
  int get hashCode => Object.hash(label, latitude, longitude, radiusKm);

  @override
  String toString() => 'ServiceZone($label, ${radiusKm}km)';
}
