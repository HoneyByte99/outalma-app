// WCAG contrast guard on the skin-tone swatches of the avatar picker.
//
// Budget line A1 is HARD: 3:1 for a meaningful interface element. The check
// mark drawn on the selected swatch IS the element that carries the selection,
// because A3 forbids letting colour alone say it.
//
// This test exists because a SINGLE check colour cannot serve the six tones:
// white on the lightest measures 1.65:1 and the dark ink on the darkest
// measures 1.14:1. Both uniform choices fail, so the colour switches at index
// 3. A number in a plan does not stop that from regressing; a red test does.
// Same idiom as test/domain/trust_contrast_test.dart.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/avatars/avatar_catalog.dart';

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

/// Relative luminance, WCAG 2.1.
double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// Contrast ratio between two OPAQUE colours.
double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('every tone check mark clears 4.5:1 on its own swatch', () {
    for (var i = 0; i < AvatarCatalog.skinTones.length; i++) {
      final tone = Color(AvatarCatalog.skinTones[i]);
      final check = Color(AvatarCatalog.toneCheckColors[i]);
      final ratio = _ratio(check, tone);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'tone $i (${AvatarCatalog.skinTones[i].toRadixString(16)}) '
            'gives ${ratio.toStringAsFixed(2)}:1, below the bar',
      );
    }
  });

  test('a single check colour would fail, which is why the table exists', () {
    const white = Color(0xFFFFFFFF);
    const ink = Color(0xFF0D1F2D);
    final lightest = Color(AvatarCatalog.skinTones.last);
    final darkest = Color(AvatarCatalog.skinTones.first);

    expect(
      _ratio(white, lightest),
      lessThan(3.0),
      reason: 'white on the lightest tone must be shown to fail',
    );
    expect(
      _ratio(ink, darkest),
      lessThan(3.0),
      reason: 'ink on the darkest tone must be shown to fail',
    );
  });

  test('the tones are ordered darkest first, which the default relies on', () {
    // `defaultToneIndex` is 1 precisely because index 0 is the darkest and its
    // black line art reads less well. If the order ever flipped, the default
    // would silently become a light tone.
    double lum(int argb) => _luminance(Color(argb));
    for (var i = 1; i < AvatarCatalog.skinTones.length; i++) {
      expect(
        lum(AvatarCatalog.skinTones[i]),
        greaterThan(lum(AvatarCatalog.skinTones[i - 1])),
        reason: 'tone $i must be lighter than tone ${i - 1}',
      );
    }
  });

  test('the shared tile background carries the ink well above 3:1', () {
    // The 40 assets share one background. The drawing ink sits on it, so this
    // is the one contrast the illustration itself cannot escape. Open Peeps
    // inks at #000000, Critters at #1e293b.
    const background = Color(0xFFEDF2F5);
    expect(_ratio(const Color(0xFF000000), background), greaterThan(3.0));
    expect(_ratio(const Color(0xFF1E293B), background), greaterThan(3.0));
  });
}
