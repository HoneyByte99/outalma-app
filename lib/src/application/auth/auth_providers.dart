import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/notification/notification_service.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../data/services/log_session_service.dart';
import '../../domain/repositories/user_repository.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firestoreProvider)),
);

final logSessionServiceProvider = Provider<LogSessionService>(
  (ref) => LogSessionService(FirebaseFunctions.instance),
);

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Side-effect provider: registers FCM token when user is authenticated.
/// Watch this from AppShell so it runs while the user is logged in.
final notificationInitProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return;

  final service = NotificationService(
    messaging: FirebaseMessaging.instance,
    db: FirebaseFirestore.instance,
    uid: authState.user.id,
  );
  await service.initialize();
});
