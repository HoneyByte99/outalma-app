/// The device-GPS plumbing behind every "use my location" affordance in the
/// app (home page's location filter, the booking address step): the
/// service-enabled check, the permission check/request, and the actual fix,
/// shared so the two do not carry two copies of the same Geolocator calls.
///
/// Deliberately returns a result instead of showing anything itself: the home
/// page's location sheet and the booking sheet surface a failure through two
/// different channels (a `SnackBar` outside a modal barrier, an in-sheet
/// banner inside one, [see `booking_request_sheet.dart`'s `_errorBanner`]), so
/// the message is the caller's call, not this helper's.
library;

import 'package:geolocator/geolocator.dart';

/// Why [resolveCurrentPosition] could not produce a fix.
enum CurrentPositionFailure {
  /// The device's location service (GPS) is off.
  serviceDisabled,

  /// The app was denied the permission, once or permanently.
  permissionDenied,

  /// The service and permission are fine but the fix itself failed (timeout,
  /// no signal, platform error).
  error,
}

/// Requests the device's current position, handling the service-enabled check
/// and the permission check/request first. [position] is non-null exactly
/// when [failure] is null.
Future<({Position? position, CurrentPositionFailure? failure})>
resolveCurrentPosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return (position: null, failure: CurrentPositionFailure.serviceDisabled);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return (position: null, failure: CurrentPositionFailure.permissionDenied);
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return (position: position, failure: null);
  } catch (_) {
    return (position: null, failure: CurrentPositionFailure.error);
  }
}
