import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// A circular avatar that displays a network photo when [photoPath] is set,
/// falling back to a coloured initials circle otherwise.
///
/// Images are cached on disk and in memory via CachedNetworkImage.
/// Load errors fall back gracefully to initials so the UI never shows a
/// broken image placeholder.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoPath,
    this.radius = 20,
  });

  final String displayName;
  final String? photoPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final initials = _initials(displayName);
    final size = radius * 2;

    final initialsWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: oc.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: radius)
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    if (photoPath == null || photoPath!.isEmpty) return initialsWidget;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Cache at 2× for Retina; avatar radius rarely exceeds 40pt → 80px
          memCacheWidth: (radius * 4).toInt(),
          memCacheHeight: (radius * 4).toInt(),
          httpHeaders: const {'Accept': '*/*'},
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: oc.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          errorWidget: (_, __, error) {
            debugPrint('[UserAvatar] image load error for $photoPath — $error');
            return initialsWidget;
          },
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
}
