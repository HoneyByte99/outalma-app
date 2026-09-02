import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/document_quad.dart';
import 'package:outalma_app/src/domain/identity/preview_projection.dart';

/// An axis-aligned quad from its normalised bounds.
DocumentQuad _rect(double left, double top, double right, double bottom) {
  return DocumentQuad(
    topLeft: (x: left, y: top),
    topRight: (x: right, y: top),
    bottomRight: (x: right, y: bottom),
    bottomLeft: (x: left, y: bottom),
  );
}

void _expectPoint(NormPoint actual, NormPoint expected, {double eps = 1e-9}) {
  expect(actual.x, closeTo(expected.x, eps));
  expect(actual.y, closeTo(expected.y, eps));
}

void main() {
  group('projectQuadToPreview', () {
    test('leaves the quad alone at zero turns', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      final out = projectQuadToPreview(quad: quad, quarterTurns: 0);
      _expectPoint(out.topLeft, quad.topLeft);
      _expectPoint(out.bottomRight, quad.bottomRight);
    });

    test('one clockwise quarter turn, computed by hand', () {
      // (x, y) -> (1 - y, x). The plane's top-left corner (0.2, 0.3) lands at
      // (0.7, 0.2), which becomes the preview's TOP-RIGHT.
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      final out = projectQuadToPreview(quad: quad, quarterTurns: 1);
      _expectPoint(out.topRight, (x: 0.7, y: 0.2));
      _expectPoint(out.bottomRight, (x: 0.7, y: 0.8));
      _expectPoint(out.bottomLeft, (x: 0.4, y: 0.8));
      _expectPoint(out.topLeft, (x: 0.4, y: 0.2));
    });

    test('two quarter turns is a point reflection', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      final out = projectQuadToPreview(quad: quad, quarterTurns: 2);
      _expectPoint(out.bottomRight, (x: 0.8, y: 0.7));
      _expectPoint(out.topLeft, (x: 0.2, y: 0.4));
    });

    test('three quarter turns is the inverse of one', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      final once = projectQuadToPreview(quad: quad, quarterTurns: 1);
      final back = projectQuadToPreview(quad: once, quarterTurns: 3);
      _expectPoint(back.topLeft, quad.topLeft);
      _expectPoint(back.bottomRight, quad.bottomRight);
    });

    test('four quarter turns is the identity', () {
      final quad = _rect(0.15, 0.25, 0.85, 0.55);
      final out = projectQuadToPreview(quad: quad, quarterTurns: 4);
      _expectPoint(out.topLeft, quad.topLeft);
      _expectPoint(out.bottomRight, quad.bottomRight);
    });

    test('two half turns come back to the identity', () {
      final quad = _rect(0.15, 0.25, 0.85, 0.55);
      final half = projectQuadToPreview(quad: quad, quarterTurns: 2);
      final full = projectQuadToPreview(quad: half, quarterTurns: 2);
      _expectPoint(full.topLeft, quad.topLeft);
      _expectPoint(full.bottomRight, quad.bottomRight);
    });

    test('preserves the area, whatever the turn', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      for (final turns in const [0, 1, 2, 3]) {
        final out = projectQuadToPreview(quad: quad, quarterTurns: turns);
        expect(out.area, closeTo(quad.area, 1e-9), reason: 'turns $turns');
      }
    });

    test('normalises an out-of-range or negative turn count', () {
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      final one = projectQuadToPreview(quad: quad, quarterTurns: 1);
      final five = projectQuadToPreview(quad: quad, quarterTurns: 5);
      final minusThree = projectQuadToPreview(quad: quad, quarterTurns: -3);
      _expectPoint(five.topLeft, one.topLeft);
      _expectPoint(minusThree.topLeft, one.topLeft);
    });

    test('mirrors across the vertical axis when asked', () {
      // No execution path on the document screen (both sides use the back
      // lens), so this covers the seam and not shipped behaviour.
      final quad = _rect(0.2, 0.3, 0.8, 0.6);
      final out = projectQuadToPreview(
        quad: quad,
        quarterTurns: 0,
        mirrored: true,
      );
      _expectPoint(out.topLeft, (x: 0.8, y: 0.3));
      _expectPoint(out.topRight, (x: 0.2, y: 0.3));
      expect(out.area, closeTo(quad.area, 1e-9));
    });
  });

  group('previewMatchesPlane', () {
    // The premise the whole contour rests on, and nothing in the platform
    // guarantees it: Android binds Preview, ImageCapture and ImageAnalysis
    // without a shared ViewPort.
    test('accepts a 16:9 preview over a 16:9 plane, either way round', () {
      expect(
        previewMatchesPlane(
          previewAspect: 16 / 9,
          planeWidth: 1920,
          planeHeight: 1080,
        ),
        isTrue,
      );
      expect(
        previewMatchesPlane(
          previewAspect: 16 / 9,
          planeWidth: 1080,
          planeHeight: 1920,
        ),
        isTrue,
      );
    });

    test('refuses a 4:3 preview over a 16:9 plane', () {
      // The case that would draw a contour wrong everywhere, which no
      // "is it inside the frame" net catches.
      expect(
        previewMatchesPlane(
          previewAspect: 4 / 3,
          planeWidth: 1920,
          planeHeight: 1080,
        ),
        isFalse,
      );
    });

    test('tolerates a small reporting difference', () {
      expect(
        previewMatchesPlane(
          previewAspect: 1.78,
          planeWidth: 1920,
          planeHeight: 1080,
        ),
        isTrue,
      );
    });

    test('refuses degenerate inputs rather than assuming a match', () {
      expect(
        previewMatchesPlane(
          previewAspect: 0,
          planeWidth: 1920,
          planeHeight: 1080,
        ),
        isFalse,
      );
      expect(
        previewMatchesPlane(
          previewAspect: 16 / 9,
          planeWidth: 0,
          planeHeight: 0,
        ),
        isFalse,
      );
    });
  });

  group('quadMostlyInside', () {
    // The last net against an absurd overlay: a wrong platform rotation must
    // give an ABSENT contour, never a grotesque one, and the template is still
    // on screen either way.
    test('accepts a quad well inside the frame', () {
      expect(quadMostlyInside(_rect(0.1, 0.2, 0.9, 0.7)), isTrue);
    });

    test('accepts a quad that only touches the edge', () {
      // A correct contour legitimately reaches the frame edge: that is the
      // "too close" case, and it must still be drawn.
      expect(quadMostlyInside(_rect(0.0, 0.2, 1.0, 0.7)), isTrue);
    });

    test('refuses a quad thrown almost entirely outside', () {
      // What a wrong quarter-turn produces.
      expect(quadMostlyInside(_rect(1.4, 1.3, 2.2, 1.8)), isFalse);
    });

    test('refuses when only two corners remain in frame', () {
      const halfOut = DocumentQuad(
        topLeft: (x: 0.5, y: 0.4),
        topRight: (x: 1.9, y: 0.4),
        bottomRight: (x: 1.9, y: 0.7),
        bottomLeft: (x: 0.5, y: 0.7),
      );
      expect(quadMostlyInside(halfOut), isFalse);
    });

    test('honours the margin', () {
      // A rectangle poking 0.03 past the left edge puts TWO corners out, not
      // one, so the tight margin refuses it and the generous one accepts it.
      final justOutside = _rect(-0.03, 0.2, 0.9, 0.7);
      expect(quadMostlyInside(justOutside), isTrue, reason: 'default 0.05');
      expect(quadMostlyInside(justOutside, margin: 0.01), isFalse);
    });

    test('tolerates a single corner outside', () {
      // One corner past the edge is a plausible perspective quad on a card held
      // at the frame boundary, and it must still be drawn.
      const oneOut = DocumentQuad(
        topLeft: (x: -0.2, y: 0.3),
        topRight: (x: 0.9, y: 0.25),
        bottomRight: (x: 0.9, y: 0.65),
        bottomLeft: (x: 0.1, y: 0.7),
      );
      expect(quadMostlyInside(oneOut), isTrue);
    });
  });
}
