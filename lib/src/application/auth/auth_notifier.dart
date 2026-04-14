import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/phone_otp_service.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/models/app_user.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

/// Thrown when a phone number is already associated with another account.
class PhoneTakenException implements Exception {
  @override
  String toString() => 'PhoneTakenException: phone number already in use';
}

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
          phoneE164: firebaseUser.phoneNumber,
          country: 'FR',
          activeMode: ActiveMode.client,
          createdAt: DateTime.now(),
        );
        await userRepo.upsert(appUser);
      }

      // Fire-and-forget: log the session (IP, country, device). Never blocks.
      ref.read(logSessionServiceProvider).log();

      return AuthAuthenticated(appUser);
    } catch (e, st) {
      // Log the error so we can diagnose auth issues instead of silently
      // treating every failure as "unauthenticated".
      debugPrint('[AuthNotifier] _resolveState error: $e\n$st');
      return const AuthUnauthenticated();
    }
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
  }

  // ---------------------------------------------------------------------------
  // Phone auth — OTP flow (disabled for MVP, ready to activate)
  // ---------------------------------------------------------------------------

  /// Step 1 of phone auth — sends SMS OTP.
  /// On success, transitions to [AuthPhoneVerification].
  /// On Android auto-verification, stays silent (auth state updates automatically).
  /// Throws on failure.
  Future<void> sendPhoneOtp(String phoneE164) async {
    final token = await platformSendOtp(
      ref.read(firebaseAuthProvider),
      phoneE164,
    );
    // null → Android auto-verified; authStateChanges handles the rest.
    if (token != null) {
      state = AsyncData(AuthPhoneVerification(
        verificationId: token,
        phoneNumber: phoneE164,
      ));
    }
  }

  /// Step 2 of phone auth — verifies the OTP entered by the user.
  /// On success, [authStateChanges] fires and [_resolveState] runs.
  Future<void> verifyPhoneOtp(String verificationId, String smsCode) async {
    await platformVerifyOtp(
      ref.read(firebaseAuthProvider),
      verificationId,
      smsCode,
    );
  }

  // ---------------------------------------------------------------------------
  // Phone auth — temporary no-OTP flow (MVP)
  // Uses Firebase email auth under the hood with a deterministic email
  // derived from the phone number. Replace with real OTP when ready.
  // ---------------------------------------------------------------------------

  static const _phoneDomain = 'phone.outalma.app';
  static const _phonePasswordPrefix = 'outalma_ph_';

  /// Derives a deterministic Firebase email from an E.164 phone number.
  static String _phoneToEmail(String phoneE164) {
    final digits = phoneE164.replaceAll(RegExp(r'[^\d]'), '');
    return '$digits@$_phoneDomain';
  }

  static String _phoneToPassword(String phoneE164) {
    final digits = phoneE164.replaceAll(RegExp(r'[^\d]'), '');
    return '$_phonePasswordPrefix$digits';
  }

  /// Sign up with phone number (no OTP). Creates a Firebase email account
  /// under the hood and stores the real phone in the user doc.
  /// Throws [PhoneTakenException] if the number is already in use.
  /// TODO: Replace with real OTP flow when ready.
  Future<void> signUpWithPhone({
    required String phoneE164,
    required String displayName,
  }) async {
    // Check phone uniqueness before creating the Firebase account.
    final taken = await ref.read(userRepositoryProvider).isPhoneTaken(phoneE164);
    if (taken) throw PhoneTakenException();

    final auth = ref.read(firebaseAuthProvider);
    final email = _phoneToEmail(phoneE164);
    final password = _phoneToPassword(phoneE164);

    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = AppUser(
      id: credential.user!.uid,
      displayName: displayName,
      email: '', // not a real email — phone-based account
      phoneE164: phoneE164,
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime.now(),
    );
    await ref.read(userRepositoryProvider).upsert(user);
  }

  /// Sign in with phone number (no OTP). Looks up the deterministic
  /// email derived from the phone and signs in.
  /// TODO: Replace with real OTP flow when ready.
  Future<void> signInWithPhone({required String phoneE164}) async {
    final auth = ref.read(firebaseAuthProvider);
    final email = _phoneToEmail(phoneE164);
    final password = _phoneToPassword(phoneE164);

    await auth.signInWithEmailAndPassword(email: email, password: password);
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
  /// Throws [PhoneTakenException] if the new phone is already in use.
  /// Performs an optimistic local update and reverts on failure.
  Future<void> updateProfile({
    required String displayName,
    String? phoneE164,
    String? country,
    String? photoPath,
  }) async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;

    // Check phone uniqueness if phone is changing.
    final newPhone = phoneE164 ?? current.user.phoneE164;
    if (newPhone != null &&
        newPhone.isNotEmpty &&
        newPhone != current.user.phoneE164) {
      final taken = await ref
          .read(userRepositoryProvider)
          .isPhoneTaken(newPhone, excludeUid: current.user.id);
      if (taken) throw PhoneTakenException();
    }

    final updated = current.user.copyWith(
      displayName: displayName,
      phoneE164: newPhone,
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
  /// Throws [PhoneTakenException] if the phone number is already in use.
  Future<void> createUserDoc({
    required String uid,
    required String displayName,
    required String email,
    String? phoneE164,
  }) async {
    if (phoneE164 != null && phoneE164.isNotEmpty) {
      final taken = await ref.read(userRepositoryProvider).isPhoneTaken(phoneE164);
      if (taken) throw PhoneTakenException();
    }

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
