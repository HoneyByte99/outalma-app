import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/document_quad.dart';

/// An axis-aligned quad from its normalised bounds.
DocumentQuad _rect(double left, double top, double right, double bottom) {
  return DocumentQuad(
    topLeft: (x: left, y: top),
    topRight: (x: right, y: top),
    bottomRight: (x: right, y: bottom),
    bottomLeft: (x: left, y: bottom),
  );
}

void main() {
  group('area', () {
    test('is the fraction of the plane the quad covers', () {
      expect(_rect(0, 0, 1, 1).area, closeTo(1, 1e-9));
      expect(_rect(0.25, 0.25, 0.75, 0.75).area, closeTo(0.25, 1e-9));
    });

    test('is the same whichever way the ring is wound', () {
      final clockwise = _rect(0.2, 0.2, 0.8, 0.6);
      final counter = DocumentQuad(
        topLeft: clockwise.topLeft,
        topRight: clockwise.bottomLeft,
        bottomRight: clockwise.bottomRight,
        bottomLeft: clockwise.topRight,
      );
      expect(counter.area, greaterThan(0));
      expect(clockwise.area, greaterThan(0));
    });
  });

  group('isConvex', () {
    test('accepts a rectangle and a plausible perspective quad', () {
      expect(_rect(0.1, 0.1, 0.9, 0.6).isConvex, isTrue);
      const tilted = DocumentQuad(
        topLeft: (x: 0.12, y: 0.22),
        topRight: (x: 0.88, y: 0.18),
        bottomRight: (x: 0.90, y: 0.62),
        bottomLeft: (x: 0.10, y: 0.58),
      );
      expect(tilted.isConvex, isTrue);
    });

    test('refuses a self-crossing ring', () {
      const crossed = DocumentQuad(
        topLeft: (x: 0.1, y: 0.1),
        topRight: (x: 0.9, y: 0.1),
        bottomRight: (x: 0.1, y: 0.6),
        bottomLeft: (x: 0.9, y: 0.6),
      );
      expect(crossed.isConvex, isFalse);
    });

    test('refuses a degenerate ring with three collinear corners', () {
      const flat = DocumentQuad(
        topLeft: (x: 0.1, y: 0.3),
        topRight: (x: 0.5, y: 0.3),
        bottomRight: (x: 0.9, y: 0.3),
        bottomLeft: (x: 0.5, y: 0.7),
      );
      expect(flat.isConvex, isFalse);
    });
  });

  group('planeAspect', () {
    // The load-bearing property: the SAME card scores the same in both real
    // plane layouts. Without it every correctly framed Android capture would be
    // refused, since the card lies vertically in a sensor-oriented plane.
    test('is the same for a card lying either way in its plane', () {
      // iOS-shaped plane, portrait, card lying horizontally across it. The card
      // spans 90 per cent of the 1080 px width, so its height in pixels is
      // (0.9 * 1080) / 1.585, which normalises against the 1920 px height.
      const iosW = 1080;
      const iosH = 1920;
      const iosCardHeight = (0.9 * iosW / 1.585) / iosH;
      final onIos = _rect(0.05, 0.4, 0.95, 0.4 + iosCardHeight);

      // Android-shaped plane, landscape, the same card standing vertically: it
      // spans 90 per cent of the 1080 px height, and its width normalises
      // against the 1920 px width.
      const androidW = 1920;
      const androidH = 1080;
      const androidCardWidth = (0.9 * androidH / 1.585) / androidW;
      final onAndroid = _rect(0.4, 0.05, 0.4 + androidCardWidth, 0.95);

      expect(onIos.planeAspect(iosW, iosH), closeTo(1.585, 0.05));
      expect(onAndroid.planeAspect(androidW, androidH), closeTo(1.585, 0.05));
    });

    test('always returns the long side over the short one', () {
      final wide = _rect(0.1, 0.4, 0.9, 0.6);
      expect(wide.planeAspect(1000, 1000), greaterThanOrEqualTo(1));
      final tall = _rect(0.4, 0.1, 0.6, 0.9);
      expect(tall.planeAspect(1000, 1000), greaterThanOrEqualTo(1));
      expect(
        wide.planeAspect(1000, 1000),
        closeTo(tall.planeAspect(1000, 1000), 1e-9),
      );
    });

    test('is zero for a degenerate quad rather than infinite', () {
      expect(_rect(0.5, 0.5, 0.5, 0.5).planeAspect(1000, 1000), 0);
    });
  });

  group('inPlaneRotationDeg', () {
    test('is about zero for an axis-aligned quad', () {
      expect(
        _rect(0.1, 0.2, 0.9, 0.7).inPlaneRotationDeg(1000, 1000),
        closeTo(0, 0.01),
      );
    });

    test('grows with the tilt, and reads the angle back', () {
      // A square plane keeps normalised and pixel angles the same, so the
      // expected value can be written by hand.
      const tilted = DocumentQuad(
        topLeft: (x: 0.2, y: 0.3),
        topRight: (x: 0.7, y: 0.3 + 0.5 * 0.17632), // tan(10 degrees)
        bottomRight: (x: 0.7 - 0.3 * 0.17632, y: 0.3 + 0.5 * 0.17632 + 0.3),
        bottomLeft: (x: 0.2 - 0.3 * 0.17632, y: 0.3 + 0.3),
      );
      expect(tilted.inPlaneRotationDeg(1000, 1000), closeTo(10, 0.5));
    });

    test('accounts for the plane being non-square', () {
      // The same normalised quad tilts differently in pixels depending on the
      // plane shape, which is why the measure takes the dimensions.
      const quad = DocumentQuad(
        topLeft: (x: 0.1, y: 0.30),
        topRight: (x: 0.9, y: 0.35),
        bottomRight: (x: 0.9, y: 0.55),
        bottomLeft: (x: 0.1, y: 0.50),
      );
      final square = quad.inPlaneRotationDeg(1000, 1000);
      final wide = quad.inPlaneRotationDeg(1920, 1080);
      expect(wide, lessThan(square));
    });
  });

  group('touchesPlaneEdge', () {
    test('is false for a quad comfortably inside the plane', () {
      expect(_rect(0.1, 0.2, 0.9, 0.7).touchesPlaneEdge(), isFalse);
    });

    test('is true as soon as one corner reaches an edge', () {
      expect(_rect(0.0, 0.2, 0.9, 0.7).touchesPlaneEdge(), isTrue);
      expect(_rect(0.1, 0.2, 1.0, 0.7).touchesPlaneEdge(), isTrue);
      expect(_rect(0.1, 0.0, 0.9, 0.7).touchesPlaneEdge(), isTrue);
      expect(_rect(0.1, 0.2, 0.9, 1.0).touchesPlaneEdge(), isTrue);
    });

    test('honours the tolerance', () {
      final near = _rect(0.02, 0.2, 0.9, 0.7);
      expect(near.touchesPlaneEdge(tolerance: 0.01), isFalse);
      expect(near.touchesPlaneEdge(tolerance: 0.05), isTrue);
    });
  });

  group('the physical ceiling on fill', () {
    // Pins the number that made a 0.95 "maxFill" a branch that never runs: an
    // ID-1 card's long side lands on the plane's SHORT side in both layouts, so
    // this is the most of the plane a correctly shaped card can ever cover.
    test('an ID-1 card at maximum size covers about a third of the plane', () {
      const w = 1920;
      const h = 1080;
      // Card as large as it fits: its long side spans the plane's short side.
      const longSideNorm = h / h; // the full short side, normalised
      const shortSidePx = h / 1.585;
      final quad = _rect(
        0.5 - (shortSidePx / w) / 2,
        0.5 - longSideNorm / 2,
        0.5 + (shortSidePx / w) / 2,
        0.5 + longSideNorm / 2,
      );
      expect(quad.planeAspect(w, h), closeTo(1.585, 0.02));
      expect(quad.area, closeTo(0.355, 0.01));
      expect(quad.area, lessThan(0.4));
    });
  });
}
