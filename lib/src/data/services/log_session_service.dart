import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Calls the `logSession` Cloud Function to record a login event
/// (IP, country, platform, device model, app version).
///
/// Failures are swallowed — session logging must never block the auth flow.
class LogSessionService {
  const LogSessionService(this._functions);
  final FirebaseFunctions _functions;

  Future<void> log() async {
    try {
      final platform = _platformString();
      final deviceModel = await _deviceModel();
      final appVersion = await _appVersion();
      final sessionId = _generateId();

      await _functions.httpsCallable('logSession').call<void>({
        'platform': platform,
        'deviceModel': deviceModel,
        'appVersion': appVersion,
        'sessionId': sessionId,
      });
    } catch (e) {
      // Intentionally silent — logging must not break the auth flow.
      debugPrint('[LogSessionService] error: $e');
    }
  }

  static String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure()
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return '${ts.toRadixString(16)}-$rand';
  }

  static String _platformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  static Future<String?> _deviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        return web.browserName.name;
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.model;
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.utsname.machine;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
