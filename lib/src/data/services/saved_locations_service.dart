import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'saved_locations';
const _kMaxSaved = 5;

class SavedLocation {
  const SavedLocation({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });

  final String label; // Custom name: "Maison", "Bureau"
  final String address; // Full address from Places API
  final double lat;
  final double lng;
  final double radiusKm;

  Map<String, dynamic> toJson() => {
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
    'radiusKm': radiusKm,
  };

  factory SavedLocation.fromJson(Map<String, dynamic> m) => SavedLocation(
    label: m['label'] as String? ?? '',
    address: m['address'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble() ?? 0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0,
    radiusKm: (m['radiusKm'] as num?)?.toDouble() ?? 30,
  );
}

class SavedLocationsNotifier extends Notifier<List<SavedLocation>> {
  @override
  List<SavedLocation> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(SavedLocation.fromJson)
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> add(SavedLocation location) async {
    // Avoid duplicates by address
    final filtered = state.where((l) => l.address != location.address).toList();
    final updated = [location, ...filtered].take(_kMaxSaved).toList();
    state = updated;
    await _persist();
  }

  Future<void> remove(int index) async {
    state = [...state]..removeAt(index);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(state.map((l) => l.toJson()).toList()),
    );
  }
}

final savedLocationsProvider =
    NotifierProvider<SavedLocationsNotifier, List<SavedLocation>>(
      SavedLocationsNotifier.new,
    );
