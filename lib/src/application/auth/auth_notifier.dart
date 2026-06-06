import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/callable_function_client.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/models/app_user.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

// ---------------------------------------------------------------------------
// Email verification link — round-trip target after the user clicks the
// "Verify your email" link sent by Firebase Auth.
// ---------------------------------------------------------------------------

/// Bundle identifiers used to deep-link back to the installed Outalma app
/// via Universal Links / App Links.
const _iosBundleId = 'com.honeybyte.outalmaApp';
const _androidPackage = 'com.honeybyte.outalma_app';

/// Continue URL — must point at a domain listed in the project's Firebase
/// Authentication "Authorized domains" list and in the iOS Associated
/// Domains / Android intent filters.
const _emailVerifyContinueUrl =
    'https://outalmaservice-d1e59.firebaseapp.com/__/auth/links';

/// Thrown when a phone number is already associated with another account.
class PhoneTakenException implements Exception {
  @override
  String toString() => 'PhoneTakenException: phone number already in use';
}

/// Thrown when the user typed an invalid OTP code or the code has expired.
class InvalidOtpException implements Exception {
  @override
  String toString() => 'InvalidOtpException: invalid or expired code';
}

/// Result of [AuthNotifier.phoneSignInWithOtp].
class PhoneSignInResult {
  const PhoneSignInResult({required this.signedIn});

  /// `true` when the OTP matched an existing Outalma account and the client
  /// is now authenticated. `false` when the phone has no account yet — the
  /// caller should redirect to the sign-up flow.
  final bool signedIn;

  bool get isNewUser => !signedIn;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  // ignore: cancel_subscriptions — cancelled via ref.onDispose(_authSub.cancel) below.
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
      // Retry transient read failures (network blips) before giving up, so a
      // momentary Firestore error does not force an authenticated user back to
      // the sign-in screen.
      AppUser? appUser;
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          appUser = await userRepo.getById(firebaseUser.uid);
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 300 * (attempt + 1)),
            );
          }
        }
      }
      if (lastError != null) throw lastError;
      if (appUser == null) {
        // Defensive: phone signups and email magic-link signups both create
        // the Firestore user doc through dedicated paths (Cloud Function or
        // [completeEmailMagicLink]). If we still end up here, write a minimal
        // doc WITHOUT `phoneE164` — the Firestore rule blocks client writes
        // to that field (security review C1).
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
    } catch (e, st) {
      debugPrint('[AuthNotifier] _resolveState error: $e\n$st');
      return const AuthUnauthenticated();
    }
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthProvider).signOut();
  }

  /// Permanently deletes the current user's account and personal data via a
  /// server-authoritative Cloud Function, then signs out locally.
  /// Required by App Store 5.1.1(v) and Google Play.
  Future<void> deleteAccount() async {
    await const CallableFunctionClient().call('deleteMyAccount');
    await ref.read(firebaseAuthProvider).signOut();
  }

  // ---------------------------------------------------------------------------
  // Phone authentication via OTP — production flow (Twilio Verify backend)
  // All flows are server-authoritative through Cloud Functions.
  // ---------------------------------------------------------------------------

  /// Sends an OTP to [phoneE164] via Twilio (SMS by default).
  ///
  /// Throws [FirebaseFunctionsException] on Twilio failure or invalid input.
  Future<void> requestPhoneOtp(
    String phoneE164, {
    String channel = 'sms',
  }) async {
    await const CallableFunctionClient().call(
      'requestPhoneOtp',
      data: {'phone': phoneE164, 'channel': channel},
    );
  }

  /// Verifies [code] and signs in the existing Outalma account behind
  /// [phoneE164]. Returns a [PhoneSignInResult] indicating whether the
  /// account exists.
  ///
  /// On success, [authStateChanges] fires and [_resolveState] runs.
  /// Throws [InvalidOtpException] when the code is wrong/expired.
  Future<PhoneSignInResult> phoneSignInWithOtp(
    String phoneE164,
    String code,
  ) async {
    try {
      final result = await const CallableFunctionClient().call(
        'verifyPhoneOtpAndSignIn',
        data: {'phone': phoneE164, 'code': code},
      );

      final newUser = result['newUser'] == true;
      if (newUser) {
        return const PhoneSignInResult(signedIn: false);
      }

      final token = result['customToken'] as String?;
      if (token == null) {
        throw StateError('verifyPhoneOtpAndSignIn returned no customToken');
      }
      await ref.read(firebaseAuthProvider).signInWithCustomToken(token);
      return const PhoneSignInResult(signedIn: true);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') throw InvalidOtpException();
      rethrow;
    }
  }

  /// Verifies [code] and creates a new account for [phoneE164].
  ///
  /// On success, [authStateChanges] fires and [_resolveState] runs.
  /// Throws [InvalidOtpException] when the code is wrong/expired.
  /// Throws [PhoneTakenException] when the number is already registered.
  Future<void> phoneSignUpWithOtp({
    required String phoneE164,
    required String code,
    required String displayName,
    required String country,
  }) async {
    try {
      final result = await const CallableFunctionClient().call(
        'verifyPhoneOtpAndSignUp',
        data: {
          'phone': phoneE164,
          'code': code,
          'displayName': displayName,
          'country': country,
        },
      );

      final token = result['customToken'] as String?;
      if (token == null) {
        throw StateError('verifyPhoneOtpAndSignUp returned no customToken');
      }
      await ref.read(firebaseAuthProvider).signInWithCustomToken(token);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') throw InvalidOtpException();
      if (e.code == 'already-exists') throw PhoneTakenException();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Profile mutations
  // ---------------------------------------------------------------------------

  /// Switches the active mode for the current user.
  Future<void> switchMode(ActiveMode mode) async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;

    final updated = current.user.copyWith(activeMode: mode);
    state = AsyncData(AuthAuthenticated(updated));

    try {
      await ref.read(userRepositoryProvider).upsert(updated);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Updates mutable profile fields. **Phone number is intentionally not
  /// editable here** — changing the phone requires re-verification via OTP
  /// and is handled by a dedicated flow (TBD).
  Future<void> updateProfile({
    required String displayName,
    String? country,
    String? photoPath,
  }) async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;

    final updated = current.user.copyWith(
      displayName: displayName,
      country: country ?? current.user.country,
      photoPath: photoPath ?? current.user.photoPath,
    );

    state = AsyncData(AuthAuthenticated(updated));

    try {
      await ref.read(userRepositoryProvider).upsert(updated);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Email authentication — password-based with one-time email verification
  // ---------------------------------------------------------------------------
  //
  // Sign-up: create Firebase Auth account with email+password, write Firestore
  // user doc, then send a verification email. The user is signed in
  // immediately but `firebaseUser.emailVerified` stays `false` until they
  // click the link in their inbox.
  //
  // Sign-in: standard `signInWithEmailAndPassword`. Optional "forgot password"
  // sends a reset link.
  //
  // The verification link round-trips through Firebase's action handler and
  // back into the app via Universal Links / App Links — handled in
  // [completeEmailVerification].

  /// Creates a new account via email + password, then sends a one-time email
  /// verification link to the new mailbox. The user is signed in on success
  /// regardless of whether the email is verified yet.
  Future<void> signUpWithEmailPassword({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final auth = ref.read(firebaseAuthProvider);
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('createUserWithEmailAndPassword returned no user');
    }

    // Set displayName on the Firebase Auth user first so the auth listener
    // (in [_resolveState]) can pick it up if it runs before our upsert.
    try {
      await user.updateDisplayName(displayName);
    } catch (e) {
      debugPrint('[AuthNotifier] updateDisplayName failed: $e');
    }

    // Explicitly create the Firestore user doc. Read any doc the auth listener
    // may have created in the meantime so we preserve `createdAt` (Firestore
    // rule requires it unchanged on update).
    final repo = ref.read(userRepositoryProvider);
    final existing = await repo.getById(user.uid);
    await repo.upsert(
      AppUser(
        id: user.uid,
        displayName: displayName,
        email: email,
        country: existing?.country ?? 'FR',
        activeMode: existing?.activeMode ?? ActiveMode.client,
        createdAt: existing?.createdAt ?? DateTime.now(),
        // Consent proof — the sign-up screen gates submission on acceptance.
        termsAcceptedAt: existing?.termsAcceptedAt ?? DateTime.now(),
      ),
    );

    // Send the verification mail. Failures here do NOT abort sign-up — the
    // user is already in. UI can offer "Resend" via [resendVerificationEmail].
    try {
      await user.sendEmailVerification(
        ActionCodeSettings(
          url: _emailVerifyContinueUrl,
          handleCodeInApp: true,
          iOSBundleId: _iosBundleId,
          androidPackageName: _androidPackage,
          androidInstallApp: true,
          androidMinimumVersion: '21',
        ),
      );
    } catch (e) {
      debugPrint('[AuthNotifier] sendEmailVerification failed: $e');
    }
  }

  /// Signs the user in via email + password. No magic link involved.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await ref
        .read(firebaseAuthProvider)
        .signInWithEmailAndPassword(email: email, password: password);
  }

  /// Re-sends the verification email to the currently signed-in user.
  /// Useful when the user closed the original mail or wants a fresh link.
  Future<void> resendVerificationEmail() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    await user.sendEmailVerification(
      ActionCodeSettings(
        url: _emailVerifyContinueUrl,
        handleCodeInApp: true,
        iOSBundleId: _iosBundleId,
        androidPackageName: _androidPackage,
        androidInstallApp: true,
        androidMinimumVersion: '21',
      ),
    );
  }

  /// Applies the verification oobCode embedded in a Universal Link the user
  /// clicked from their inbox. Returns `true` if the address was verified.
  ///
  /// The caller (deep-link handler in [OutalmaServiceApp]) is expected to
  /// pass the raw `oobCode` extracted from the URI query parameters.
  Future<bool> completeEmailVerification(String oobCode) async {
    final auth = ref.read(firebaseAuthProvider);
    try {
      await auth.applyActionCode(oobCode);
      await auth.currentUser?.reload();
      // Refresh state so the UI sees `emailVerified: true`.
      state = AsyncData(await _resolveState(auth.currentUser));
      return true;
    } catch (e) {
      debugPrint('[AuthNotifier] applyActionCode failed: $e');
      return false;
    }
  }
}
