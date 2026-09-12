import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/notification/notification_service.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../data/services/callable_function_client.dart';
import '../../data/services/functions_phone_otp_service.dart';
import '../../data/services/log_session_service.dart';
import '../../domain/repositories/user_repository.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';
import 'phone_otp_port.dart';

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
  (ref) => const LogSessionService(),
);

/// The callable transport, behind a provider so the four server-authoritative
/// paths that go through it (account deletion, data export, the two phone
/// verifications) can be exercised in a test without a network. The transport
/// itself throws on `FirebaseAuth.instance` long before any HTTP request when
/// no Firebase app is initialised, so without this seam those paths could not
/// be tested at all.
final callableClientProvider = Provider<CallableFunctionClient>(
  (ref) => const CallableFunctionClient(),
);

/// Overridden in widget tests so the auth pages exercise the OTP flow without
/// a network, and so a refusal can be replayed exactly as the server sends it.
final phoneOtpPortProvider = Provider<PhoneOtpPort>(
  (ref) => const FunctionsPhoneOtpService(),
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
  ref.onDispose(service.dispose);
  await service.initialize();
});
