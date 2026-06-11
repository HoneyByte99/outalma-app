import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the iOS Settings page for this app so the user can re-enable a
/// permission (notifications, microphone…) that was denied at first launch.
///
/// iOS exposes `UIApplication.openSettingsURLString` as the `app-settings:`
/// scheme, which url_launcher can open directly — no extra dependency. On
/// Android this is a no-op (returns false); the caller keeps showing its
/// guidance message instead.
Future<bool> openAppSettings() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;
  try {
    return await launchUrl(Uri(scheme: 'app-settings'));
  } catch (_) {
    return false;
  }
}
