// Tests for resolveCurrentPosition (CADRAGE booking-ux point 4): the shared
// GPS plumbing behind every "use my location" affordance. GeolocatorPlatform
// is faked (extends, never implements: the plugin's platform-interface token
// check rejects `implements`), so no real device or plugin channel is needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:outalma_app/src/domain/utils/current_position.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission,
    this.position,
    this.throwOnGetPosition = false,
  });

  bool serviceEnabled;
  LocationPermission permission;

  /// What `requestPermission()` returns; defaults to [permission] when null.
  LocationPermission? requestedPermission;
  Position? position;
  bool throwOnGetPosition;

  int requestPermissionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return requestedPermission ?? permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (throwOnGetPosition) {
      throw Exception('GPS timeout');
    }
    return Future.value(
      position ??
          Position(
            latitude: 14.6928,
            longitude: -17.4467,
            timestamp: DateTime(2026, 1, 1),
            accuracy: 5,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
    );
  }
}

void main() {
  group('resolveCurrentPosition', () {
    test('fails with serviceDisabled when location services are off', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        serviceEnabled: false,
      );

      final result = await resolveCurrentPosition();

      expect(result.position, isNull);
      expect(result.failure, CurrentPositionFailure.serviceDisabled);
    });

    test('fails with permissionDenied when denied and the request is also '
        'denied', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );

      final result = await resolveCurrentPosition();

      expect(result.position, isNull);
      expect(result.failure, CurrentPositionFailure.permissionDenied);
    });

    test('fails with permissionDenied when permanently denied', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.deniedForever,
      );

      final result = await resolveCurrentPosition();

      expect(result.position, isNull);
      expect(result.failure, CurrentPositionFailure.permissionDenied);
      // deniedForever must never trigger a permission REQUEST: the platform
      // refuses to show the prompt again once permanently denied.
      final fake = GeolocatorPlatform.instance as _FakeGeolocatorPlatform;
      expect(fake.requestPermissionCalls, 0);
    });

    test(
      'requests permission once when initially denied, then succeeds',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          permission: LocationPermission.denied,
          requestedPermission: LocationPermission.whileInUse,
        );

        final result = await resolveCurrentPosition();

        expect(result.failure, isNull);
        expect(result.position, isNotNull);
        final fake = GeolocatorPlatform.instance as _FakeGeolocatorPlatform;
        expect(fake.requestPermissionCalls, 1);
      },
    );

    test('fails with error when the fix itself throws', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        throwOnGetPosition: true,
      );

      final result = await resolveCurrentPosition();

      expect(result.position, isNull);
      expect(result.failure, CurrentPositionFailure.error);
    });

    test('returns the position when service and permission are fine', () async {
      final fixture = Position(
        latitude: 16.02,
        longitude: -16.49,
        timestamp: DateTime(2026, 1, 1),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(position: fixture);

      final result = await resolveCurrentPosition();

      expect(result.failure, isNull);
      expect(result.position?.latitude, 16.02);
      expect(result.position?.longitude, -16.49);
    });
  });
}
