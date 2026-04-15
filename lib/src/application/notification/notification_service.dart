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

  Future<void> initialize() async {
    // FCM on Flutter Web requires a VAPID key — skip until configured.
    if (kIsWeb) return;

    // 1. Request permission (required on iOS; no-op on Android 12 and below)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Get and save token
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);

    // 3. Listen for token refreshes
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) async {
    await _db.collection('users').doc(_uid).update({'pushToken': token});
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
