import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/active_mode.dart';
import '../../domain/models/app_user.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

class AuthNotifier extends AsyncNotifier<AuthState> {
  late StreamSubscription<User?> _authSub;

  @override
  Future<AuthState> build() async {
    final auth = ref.read(firebaseAuthProvider);
    final completer = Completer<AuthState>();

    _authSub = auth.authStateChanges().listen((firebaseUser) async {
      final next = await _resolveState(firebaseUser);
      if (!completer.isCompleted) {
        completer.complete(next);
      } else {
        state = AsyncData(next);
      }
    });

    ref.onDispose(_authSub.cancel);

    return completer.future;
  }

  Future<AuthState> _resolveState(User? firebaseUser) async {
    if (firebaseUser == null) return const AuthUnauthenticated();

    final userRepo = ref.read(userRepositoryProvider);

    try {
      var appUser = await userRepo.getById(firebaseUser.uid);
      if (appUser == null) {
        appUser = AppUser(
          id: firebaseUser.uid,
          displayName: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          country: 'FR',
          activeMode: ActiveMode.client,
          createdAt: DateTime.now(),
        );
        await userRepo.upsert(appUser);
      }
      return AuthAuthenticated(appUser);
    } catch (_) {
      return const AuthUnauthenticated();
    }
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
  }

  /// Switches the active mode for the current user.
  /// Updates Firestore and syncs the in-memory AuthState immediately.
  Future<void> switchMode(ActiveMode mode) async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;

    final updated = current.user.copyWith(activeMode: mode);
    // Optimistic local update.
    state = AsyncData(AuthAuthenticated(updated));

    try {
      await ref.read(userRepositoryProvider).upsert(updated);
    } catch (_) {
      // Revert on failure.
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Updates mutable profile fields for the current user.
  /// Performs an optimistic local update and reverts on failure.
  Future<void> updateProfile({
    required String displayName,
    String? phoneE164,
    String? country,
    String? photoPath,
  }) async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;

    final updated = current.user.copyWith(
      displayName: displayName,
      phoneE164: phoneE164 ?? current.user.phoneE164,
      country: country ?? current.user.country,
      photoPath: photoPath ?? current.user.photoPath,
    );

    // Optimistic local update.
    state = AsyncData(AuthAuthenticated(updated));

    try {
      await ref.read(userRepositoryProvider).upsert(updated);
    } catch (_) {
      // Revert on failure.
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Persist a user doc immediately after FirebaseAuth account creation,
  /// so displayName is set before authStateChanges fires.
  Future<void> createUserDoc({
    required String uid,
    required String displayName,
    required String email,
    String? phoneE164,
  }) async {
    final user = AppUser(
      id: uid,
      displayName: displayName,
      email: email,
      phoneE164: phoneE164,
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime.now(),
    );
    await ref.read(userRepositoryProvider).upsert(user);
  }
}
