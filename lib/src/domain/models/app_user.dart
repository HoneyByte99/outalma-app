import '../enums/active_mode.dart';

/// Server-authoritative consent proof (RGPD / CDP Senegal loi 2008-12 art. 11).
/// Written only by Cloud Functions (phone sign-up and `finalizeEmailSignUp`)
/// through the Admin SDK; clients are forbidden from writing it (firestore.rules).
/// A signed-in account whose [termsVersion] is null has no valid consent record.
class UserConsent {
  const UserConsent({this.termsVersion, this.acceptedAt});

  final String? termsVersion;
  final DateTime? acceptedAt;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.country,
    required this.activeMode,
    required this.createdAt,
    this.photoPath,
    this.phoneE164,
    this.pushToken,
    this.termsAcceptedAt,
    this.consent,
  });

  final String id;
  final String displayName;
  final String email;
  final String? photoPath;
  final String? phoneE164;
  final String country;
  final ActiveMode activeMode;
  final String? pushToken;
  final DateTime createdAt;

  /// When the user accepted the terms + privacy policy (consent proof, RGPD).
  final DateTime? termsAcceptedAt;

  /// Server-authoritative consent record (null when the account has none yet).
  final UserConsent? consent;

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoPath,
    String? phoneE164,
    String? country,
    ActiveMode? activeMode,
    String? pushToken,
    DateTime? createdAt,
    DateTime? termsAcceptedAt,
    UserConsent? consent,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoPath: photoPath ?? this.photoPath,
      phoneE164: phoneE164 ?? this.phoneE164,
      country: country ?? this.country,
      activeMode: activeMode ?? this.activeMode,
      pushToken: pushToken ?? this.pushToken,
      createdAt: createdAt ?? this.createdAt,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      // Preserve the server-side consent through local copies (switchMode /
      // updateProfile) so the router's consent gate does not falsely fire.
      consent: consent ?? this.consent,
    );
  }
}
