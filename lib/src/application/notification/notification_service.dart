import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Handles FCM token registration and foreground message display.
///
/// Call [initialize] once after Firebase.initializeApp() and the user is
/// authenticated. It does nothing on iOS if permissions are denied.
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

  Future<void> initialize() async {
    // FCM on Flutter Web requires a VAPID key — skip until configured.
    if (kIsWeb) return;

    // 1. Listen for token refreshes FIRST. On iOS the FCM token often becomes
    //    available only after the APNs token arrives (a few seconds post-launch);
    //    subscribing first guarantees we never miss that late token even if the
    //    eager getToken() below returns null or throws.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

    // 2. Request permission (required on iOS; Android 13+ prompts; older Android no-op)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (kDebugMode) debugPrint('[Notif] permission denied — no token will register');
      return;
    }

    // 3. On Apple platforms the FCM token requires the APNs token, which is not
    //    ready at the instant the app launches. Poll briefly so getToken() does
    //    not throw `apns-token-not-set`.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 12; attempt++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apnsToken == null && kDebugMode) {
        debugPrint('[Notif] APNs token still null after ~6s — '
            'check APNs key in Firebase + push entitlement');
      }
    }

    // 4. Get and save the FCM token. Guarded: getToken() can still throw if the
    //    APNs token is not set yet — onTokenRefresh (step 1) will deliver it.
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      } else if (kDebugMode) {
        debugPrint('[Notif] getToken() returned null (APNs not ready?)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Notif] getToken() failed: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
  }

  Future<void> _saveToken(String token) async {
    try {
      // set+merge (not update) so a missing doc never throws; rules allow the
      // owner to write pushToken on their own document.
      await _db.collection('users').doc(_uid).set(
        {'pushToken': token},
        SetOptions(merge: true),
      );
      if (kDebugMode) debugPrint('[Notif] pushToken saved for $_uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Notif] failed to save pushToken: $e');
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
          content: Text(body.isNotEmpty ? '$title — $body' : title),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }
}
