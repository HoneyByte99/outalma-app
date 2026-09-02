import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_theme.dart';
import '../../domain/avatars/avatar_catalog.dart';

/// A circular avatar, resolved in one order and one order only: the imported
/// photo, then the illustrated avatar, then a coloured initials circle.
///
/// The three are mutually exclusive in practice, because `setProfileImage`
/// writes them that way, so the cascade is DEFENSIVE: it serves documents
/// written before that rule and anything the Admin SDK writes.
///
/// A photo that fails to load falls back to the avatar rather than jumping
/// straight to initials, which is why the fallback is a local variable used in
/// two places rather than a single early return.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoPath,
    this.avatarId,
    this.radius = 20,
  });

  final String displayName;
  final String? photoPath;

  /// Catalogue token, resolved by [AvatarCatalog.parse]. An unknown value
  /// resolves to null and the widget falls back to initials, so a profile
  /// carrying an avatar shipped in a newer build degrades instead of breaking.
  final String? avatarId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final initials = _initials(displayName);
    final size = radius * 2;

    final initialsWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: oc.primary, shape: BoxShape.circle),
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

    final avatarWidget = _buildIllustration(oc, size);
    // The photo failing to load must land here too, not on initials.
    final fallback = avatarWidget ?? initialsWidget;

    if (photoPath == null || photoPath!.isEmpty) return fallback;

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
            debugPrint('[UserAvatar] image load error for $photoPath: $error');
            return fallback;
          },
        ),
      ),
    );
  }

  /// Renders the catalogue illustration, or null when there is nothing to
  /// render.
  Widget? _buildIllustration(OutalmaColors oc, double size) {
    final ref = AvatarCatalog.parse(avatarId);
    if (ref == null) return null;

    final tint = ref.toneIndex == null ? null : _toneMappers[ref.toneIndex!];

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        // The background BAKED INTO the assets, so the disc and the drawing
        // cannot show a seam. Deliberately not `oc.surfaceVariant`, which
        // becomes #252C37 in the dark theme and would swallow the black line
        // art: an avatar is a picture, and pictures do not invert.
        child: ColoredBox(
          color: const Color(AvatarCatalog.tileBackgroundArgb),
          child: SvgPicture.asset(
            ref.assetPath,
            width: size,
            height: size,
            // Source and box are both square (the viewBox is 704x704 for a
            // human, 100x100 for an animal), so cover neither crops nor
            // stretches; it is here to keep that true if a viewBox ever
            // changes.
            fit: BoxFit.cover,
            colorMapper: tint,
            // Decoding an asset is asynchronous, so the first frame must not be
            // a hole. Same tinted disc the photo path already uses.
            placeholderBuilder: (_) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: oc.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One CONST mapper per tone, built once.
///
/// `colorMapper` takes part in `SvgCacheKey`'s `hashCode` and `==`, so a mapper
/// without value equality would miss the cache on every rebuild and re-parse
/// the SVG: invisible in a test, visible while scrolling a chat list. Const
/// instances make them identical by construction, and the `==` below is the
/// belt on top.
const List<_SkinToneMapper> _toneMappers = <_SkinToneMapper>[
  _SkinToneMapper(0),
  _SkinToneMapper(1),
  _SkinToneMapper(2),
  _SkinToneMapper(3),
  _SkinToneMapper(4),
  _SkinToneMapper(5),
];

/// Substitutes the generator's magenta sentinel for the chosen skin tone, and
/// leaves every other colour alone.
@immutable
class _SkinToneMapper extends ColorMapper {
  const _SkinToneMapper(this.toneIndex);

  final int toneIndex;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    // toARGB32() rather than the deprecated .value, which
    // `flutter analyze --fatal-warnings` refuses on this SDK.
    if (color.toARGB32() == AvatarCatalog.skinSentinelArgb) {
      return Color(AvatarCatalog.skinTones[toneIndex]);
    }
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is _SkinToneMapper && other.toneIndex == toneIndex;

  @override
  int get hashCode => toneIndex.hashCode;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
}
