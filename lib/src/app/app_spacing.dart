import 'package:flutter/material.dart';

/// Canonical spacing scale for Outalma.
///
/// Use these constants everywhere instead of arbitrary numbers. They form a
/// musical scale (4 → 8 → 12 → 16 → 20 → 24 → 32) that keeps layouts
/// breathing consistently. Anything below 4 should be 0 - there is no halfway.
///
/// Naming follows Material 3 conventions:
/// - `xs` = 4 (tight inline gaps, chip padding)
/// - `s`  = 8 (between icon and label, dense lists)
/// - `m`  = 12 (default inter-element gap)
/// - `l`  = 16 (card padding, default section margin)
/// - `xl` = 20 (between cards in a list)
/// - `xxl` = 24 (between major sections)
/// - `xxxl` = 32 (page-level breathing room)
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // EdgeInsets convenience.
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: l);
  static const EdgeInsets card = EdgeInsets.all(l);
  static const EdgeInsets cardCompact = EdgeInsets.all(m);
  static const EdgeInsets section = EdgeInsets.symmetric(vertical: xl);

  // Touch targets - minimum tappable height (Material 48dp; ≥ iOS HIG 44pt).
  static const double minTouchTarget = 48;

  // Border radius scale.
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 20;
}
