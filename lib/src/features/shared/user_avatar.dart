import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// A circular avatar that displays a network photo when [photoPath] is set,
/// falling back to a coloured initials circle otherwise.
///
/// Image load errors also fall back gracefully to initials so the UI never
/// shows a broken image placeholder.
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
      child: Text(
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
        child: Image.network(
          photoPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initialsWidget,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: oc.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
}
