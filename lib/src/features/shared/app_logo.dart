import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// The Outalma brand logo (house + key mark + wordmark).
///
/// The source artwork is dark navy ink, which vanishes on a dark background.
/// A recoloured light-ink variant is shipped alongside it and selected
/// automatically from the current theme brightness, so the logo stays legible
/// in both light and dark mode without a white matte halo.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height, this.fit = BoxFit.contain});

  /// Rendered height in logical pixels. Width follows the intrinsic ratio.
  final double? height;
  final BoxFit fit;

  static const _light = 'assets/images/logo_icon_cropped.png';
  static const _dark = 'assets/images/logo_icon_cropped_dark.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      context.isDark ? _dark : _light,
      height: height,
      fit: fit,
    );
  }
}
