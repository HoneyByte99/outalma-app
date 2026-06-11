import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Handles FCM token registration and foreground message display.
///
/// Call [initialize] once after Firebase.initializeApp() and the user is
/// authenticated. It does nothing on iOS if permissions are denied.
///
/// While we are diagnosing "others don't receive notifications", [initialize]
/// writes a `notifDebug` map on the user's document at every step so we can
/// read the real failure cause remotely (no device logs needed). Remove the
/// `_writeDebug` calls once delivery is confirmed healthy for real users.
class NotificationService {
  NotificationService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore db,
    required String uid,
  }) : _messaging = messaging,
       _db = db,
       _uid = uid;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final String _uid;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Reads the current notification authorization status without prompting.
  /// Drives the in-app "notifications disabled" banner.
  static Future<AuthorizationStatus> currentStatus() async {
    if (kIsWeb) return AuthorizationStatus.authorized;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<void> initialize() async {
    // FCM on Flutter Web requires a VAPID key — skip until configured.
    if (kIsWeb) return;

    // 1. Listen for token refreshes FIRST. On iOS the FCM token often becomes
    //    available only after the APNs token arrives (a few seconds post-launch);
    //    subscribing first guarantees we never miss that late token even if the
    //    eager getToken() below returns null or throws.
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

    // 2. Request permission (required on iOS; Android 13+ prompts; older Android
    //    no-op). On iOS the OS prompt only ever shows once; a later call just
    //    returns the current status, which is how the resume-time re-init heals
    //    a user who toggled notifications on in Settings.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    await _writeDebug('permission_resolved', authStatus: status.toString());

    if (status == AuthorizationStatus.denied ||
        status == AuthorizationStatus.notDetermined) {
      // No token will ever register while denied. The in-app banner (driven by
      // currentStatus()) prompts the user to enable it in iOS Settings; the
      // resume listener re-runs this method once they come back.
      if (kDebugMode) {
        debugPrint('[Notif] permission $status — no token will register');
      }
      return;
    }

    // 3. On Apple platforms the FCM token requires the APNs token, which is not
    //    ready at the instant the app launches (the AppDelegate triggers
    //    registerForRemoteNotifications). Poll briefly so getToken() does not
    //    throw `apns-token-not-set`; onTokenRefresh (step 1) catches the late one.
    var apnsPresent = true;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          apnsToken = await _messaging.getAPNSToken();
        } catch (_) {
          // ignore; retry
        }
        if (apnsToken != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      apnsPresent = apnsToken != null;
      await _writeDebug('apns_polled', apnsPresent: apnsPresent);
    }

    // 4. Get and save the FCM token. Guarded: getToken() can still throw if the
    //    APNs token is not set yet — onTokenRefresh (step 1) will deliver it.
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
        await _writeDebug('token_saved', fcmTokenPresent: true);
      } else {
        await _writeDebug('token_null', apnsPresent: apnsPresent);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Notif] getToken() failed: $e');
      await _writeDebug(
        'getToken_threw',
        apnsPresent: apnsPresent,
        fcmError: e.toString(),
      );
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
  }

  Future<void> _saveToken(String token) async {
    try {
      // set+merge (not update) so a missing doc never throws; rules allow the
      // owner to write pushToken on their own document.
      await _db.collection('users').doc(_uid).set({
        'pushToken': token,
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('[Notif] pushToken saved for $_uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Notif] failed to save pushToken: $e');
    }
  }

  /// Writes a diagnostic snapshot to `users/{uid}.notifDebug`. Best-effort:
  /// never throws into the init flow.
  Future<void> _writeDebug(
    String step, {
    String? authStatus,
    bool? apnsPresent,
    bool? fcmTokenPresent,
    String? fcmError,
  }) async {
    try {
      await _db.collection('users').doc(_uid).set({
        'notifDebug': {
          'step': step,
          'platform': defaultTargetPlatform.toString(),
          if (authStatus != null) 'authStatus': authStatus,
          if (apnsPresent != null) 'apnsPresent': apnsPresent,
          if (fcmTokenPresent != null) 'fcmTokenPresent': fcmTokenPresent,
          if (fcmError != null) 'fcmError': fcmError,
          'ts': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Diagnostics must never break initialization.
    }
  }

  /// Call this to display an in-app SnackBar for foreground messages.
  /// Pass a [messengerKey] whose current state is looked up synchronously
  /// inside the listener (avoids async BuildContext warnings).
  /// Returns the subscription so the caller can cancel it on dispose.
  static StreamSubscription<RemoteMessage> listenForeground(
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) {
    return FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final title = notification.title ?? '';
      final body = notification.body ?? '';
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(body.isNotEmpty ? '$title: $body' : title),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }
}
