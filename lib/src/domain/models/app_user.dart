import '../enums/active_mode.dart';
import '../enums/gender.dart';

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
    this.gender,
    this.avatarId,
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

  /// The gender the person declared at sign-up. Mandatory on both sign-up
  /// paths since this field shipped, so NULL means one thing only: an account
  /// created before it existed. Every surface treats that as "unknown" and
  /// displays nothing, never a default.
  final Gender? gender;

  /// The illustrated avatar chosen from the catalogue, for people who have no
  /// photo. An opaque catalogue token, resolved by
  /// `AvatarCatalog.parse`, never a path. NULL means "no avatar chosen", and
  /// the display order is photo, then avatar, then initials.
  final String? avatarId;

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
    Gender? gender,
    String? avatarId,
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
      gender: gender ?? this.gender,
      // Present for the same reason as every field above: switchMode and
      // updateProfile both rebuild the user through copyWith, so a missing
      // parameter here would reset the avatar to null on a mode toggle or a
      // name edit, which is the most ordinary path in the profile page.
      avatarId: avatarId ?? this.avatarId,
    );
  }
}
