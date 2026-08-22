// WCAG contrast guard on the identity trust tokens.
//
// Budget line A1 is HARD: 4.5:1 for body text, 3:1 for meaningful interface
// elements. The badge label is body text at 13 px, so 4.5 applies to it.
//
// This test exists because the accent colours FAIL that bar as text on their
// own tinted pill in the light theme: `success` measures 2.73:1 there and
// `warning` 2.25:1. The badge shipped that way. A number in a design document
// does not stop it from coming back; a red test does.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';

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

/// Flattens [fg] at [alpha] over [bg]: a translucent pill is not a colour, it
/// is a composite, and contrast is only defined on what the eye actually gets.
Color _over(Color fg, Color bg, double alpha) => Color.fromARGB(
  255,
  ((fg.r * alpha + bg.r * (1 - alpha)) * 255).round(),
  ((fg.g * alpha + bg.g * (1 - alpha)) * 255).round(),
  ((fg.b * alpha + bg.b * (1 - alpha)) * 255).round(),
);

void main() {
  const light = OutalmaColors.light;
  const dark = OutalmaColors.dark;

  group('light theme, the one that failed', () {
    test('verified label and icon reach AA on their pill', () {
      final pill = _over(light.success, light.cardSurface, 0.12);
      expect(_ratio(light.trustVerifiedText, pill), greaterThanOrEqualTo(4.5));
    });

    test('pending label and icon reach AA on their pill', () {
      final pill = _over(light.warning, light.cardSurface, 0.12);
      expect(_ratio(light.trustPendingText, pill), greaterThanOrEqualTo(4.5));
    });

    test('rejected label reaches AA on its pill', () {
      final pill = _over(light.error, light.cardSurface, 0.12);
      expect(_ratio(light.trustRejectedText, pill), greaterThanOrEqualTo(4.5));
    });

    test('the unverified state reaches AA on a white surface', () {
      // It carries no pill, so it is read directly on the card. It holds only
      // because the surface is white: 4.24:1 on `background` and 4.04:1 on
      // `surfaceVariant`. Hence the design rule that this state is never posed
      // on a grey surface, and hence this assertion naming the surface.
      expect(
        _ratio(light.secondaryText, light.cardSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the raw accents would NOT pass, which is why the tokens exist', () {
      // Guard against a well-meaning simplification: someone reading
      // `trustVerifiedText` and thinking "why not just use success?".
      final pill = _over(light.success, light.cardSurface, 0.12);
      expect(_ratio(light.success, pill), lessThan(4.5));
    });
  });

  group('dark theme, which never failed', () {
    test('the three states reach AA on their pills', () {
      expect(
        _ratio(
          dark.trustVerifiedText,
          _over(dark.success, dark.cardSurface, 0.12),
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _ratio(
          dark.trustPendingText,
          _over(dark.warning, dark.cardSurface, 0.12),
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _ratio(
          dark.trustRejectedText,
          _over(dark.error, dark.cardSurface, 0.12),
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  test('white on the camera scrim reaches AA against the brightest scene', () {
    // Budget line A7: the worst case is a fully white frame, so flattening the
    // scrim over white bounds every real scene.
    const white = Color(0xFFFFFFFF);
    final scrim = _over(const Color(0xFF000000), white, 0.60);
    expect(_ratio(white, scrim), greaterThanOrEqualTo(4.5));
  });
}
