import '../../domain/models/app_user.dart';

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Intermediate state: phone OTP was sent, waiting for user to enter the code.
class AuthPhoneVerification extends AuthState {
  const AuthPhoneVerification({
    required this.verificationId,
    required this.phoneNumber,
  });
  final String verificationId;
  final String phoneNumber;
}
