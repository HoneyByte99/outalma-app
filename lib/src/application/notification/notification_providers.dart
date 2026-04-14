import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../data/firestore/firestore_collections.dart';
import '../../domain/models/app_notification.dart';

/// Stream of the current user's notifications, newest first, capped at 50.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  final db = ref.watch(firestoreProvider);
  return FirestoreCollections.notifications(db: db, uid: authState.user.id)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((qs) => qs.docs.map((d) => d.data()).toList());
});

/// Derived count of unread notifications — drives the bell badge.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? [];
  return list.where((n) => !n.read).length;
});

/// Marks a single notification as read.
Future<void> markNotificationRead({
  required FirebaseFirestore db,
  required String uid,
  required String notifId,
}) async {
  await FirestoreCollections.notifications(
    db: db,
    uid: uid,
  ).doc(notifId).update({'read': true});
}

/// Batch-marks all unread notifications as read.
Future<void> markAllNotificationsRead({
  required FirebaseFirestore db,
  required String uid,
  required List<AppNotification> notifications,
}) async {
  final unread = notifications.where((n) => !n.read).toList();
  if (unread.isEmpty) return;
  final batch = db.batch();
  final col = FirestoreCollections.notifications(db: db, uid: uid);
  for (final n in unread) {
    batch.update(col.doc(n.id), {'read': true});
  }
  await batch.commit();
}
