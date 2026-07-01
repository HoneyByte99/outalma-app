import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Sends OTP via [FirebaseAuth.verifyPhoneNumber] (Android/iOS).
///
/// Returns the [verificationId] when the SMS was sent, or `null` when
/// Android auto-verified and signed in without showing the OTP screen.
/// Throws a [String] error message on failure.
Future<String?> platformSendOtp(FirebaseAuth auth, String phone) async {
  String? verificationId;
  String? error;
  final completer = Completer<void>();

  await auth.verifyPhoneNumber(
    phoneNumber: phone,
    timeout: const Duration(seconds: 60),
    verificationCompleted: (credential) async {
      // Android auto-retrieval - sign in immediately, no OTP screen needed.
      try {
        await auth.signInWithCredential(credential);
      } catch (_) {}
      if (!completer.isCompleted) completer.complete();
    },
    verificationFailed: (e) {
      error = e.message ?? e.code;
      if (!completer.isCompleted) completer.complete();
    },
    codeSent: (vId, _) {
      verificationId = vId;
      if (!completer.isCompleted) completer.complete();
    },
    codeAutoRetrievalTimeout: (_) {
      if (!completer.isCompleted) completer.complete();
    },
  );

  await completer.future;
  if (error != null) throw error!;
  return verificationId; // null → auto-verified
}

/// Verifies [code] using the [verificationId] returned by [platformSendOtp].
Future<UserCredential> platformVerifyOtp(
  FirebaseAuth auth,
  String verificationId,
  String code,
) {
  final credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: code,
  );
  return auth.signInWithCredential(credential);
}
