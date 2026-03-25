import '../enums/user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final UserRole role;
  final DateTime createdAt;

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  static AppUser fromJson(String id, Map<String, Object?> json) {
    final createdAtRaw = json['createdAt'];
    return AppUser(
      id: id,
      displayName: (json['displayName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      role: UserRole.fromString(
        (json['role'] as String?) ?? UserRole.customer.name,
      ),
      createdAt: createdAtRaw is String
          ? DateTime.parse(createdAtRaw).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
