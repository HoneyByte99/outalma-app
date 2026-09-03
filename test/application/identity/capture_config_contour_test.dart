import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/capture_config.dart';

/// The two flags that make this increment land inert, and the predicate that
/// makes "inert" true of the per-frame COST and not only of the behaviour.
///
/// A new file rather than cases added to `capture_config_test.dart`, so no
/// existing test line is touched: the additivity of this increment is a DoD line
/// proved by `git diff --numstat` showing zero deletions under `test/`.
void main() {
  group('the shipped defaults', () {
    test('the overlay is ON for the calibration pass, framing still OFF', () {
      // Build 32 (2026-09-03) is the real-phone pass itself, so the DRAWING is
      // switched on deliberately while edgeThreshold is still the placeholder:
      // an absent or flickering contour is the observation being collected.
      //
      // contourFramingEnabled stays false, and that is the line that matters:
      // an uncalibrated threshold must never reach the AUTOMATIC path, where a
      // wrong DocumentFraming would fire or block the shutter. Drawing is
      // reversible by looking away; a wrong shutter is not.
      const config = CaptureConfig();
      expect(config.contourOverlayEnabled, isTrue);
      expect(config.contourFramingEnabled, isFalse);
    });

    test('contour work is now needed, so the grid IS built', () {
      // The counterpart of the flag above, kept explicit: the per-frame cost of
      // the detector is now paid on every capture. The P1 and P5 budget lines
      // are therefore measured WITH the detector running from build 32 on.
      expect(const CaptureConfig().contourWorkNeeded, isTrue);
    });
  });

  group('contourWorkNeeded', () {
    test('is true as soon as either flag is on', () {
      expect(
        const CaptureConfig(contourOverlayEnabled: true).contourWorkNeeded,
        isTrue,
      );
      expect(
        const CaptureConfig(contourFramingEnabled: true).contourWorkNeeded,
        isTrue,
      );
      expect(
        const CaptureConfig(
          contourOverlayEnabled: true,
          contourFramingEnabled: true,
        ).contourWorkNeeded,
        isTrue,
      );
    });
  });

  group('the contour knobs reject their degenerate values', () {
    test('a grid too small for a Sobel and a peak', () {
      expect(() => CaptureConfig(contourGridLongSide: 8), throwsAssertionError);
    });

    test('a negative gradient threshold', () {
      expect(() => CaptureConfig(edgeThreshold: -1), throwsAssertionError);
    });

    test('an edge support outside its fraction', () {
      expect(() => CaptureConfig(minEdgeSupport: 0), throwsAssertionError);
      expect(() => CaptureConfig(minEdgeSupport: 1.5), throwsAssertionError);
    });

    test('a fill that is not a fraction of the plane', () {
      expect(() => CaptureConfig(minFill: 0), throwsAssertionError);
      expect(() => CaptureConfig(minFill: 1), throwsAssertionError);
    });

    test('a tolerance that accepts nothing', () {
      expect(() => CaptureConfig(aspectTolerance: 0), throwsAssertionError);
    });

    test('a rotation range with no nearest axis', () {
      expect(() => CaptureConfig(maxRotationDeg: 0), throwsAssertionError);
      expect(() => CaptureConfig(maxRotationDeg: 45), throwsAssertionError);
    });

    test('a smoothing weight outside its range', () {
      expect(() => CaptureConfig(contourSmoothing: 0), throwsAssertionError);
      expect(() => CaptureConfig(contourSmoothing: 1.2), throwsAssertionError);
    });

    test('a run length of zero on either side of the hysteresis', () {
      expect(() => CaptureConfig(acquireFrames: 0), throwsAssertionError);
      expect(() => CaptureConfig(loseFrames: 0), throwsAssertionError);
    });

    test('a grace of zero, which would never override a bad framing', () {
      expect(() => CaptureConfig(framingGraceMs: 0), throwsAssertionError);
    });
  });

  group(
    'maxRotationDeg stays inside what the detector window can capture (M2)',
    () {
      test('the shipped default fits', () {
        // Guards the coupling by formula, not by a copy of the number: if
        // either maxRotationDeg or edgeWindowFraction moves without the other,
        // this fails instead of the rotation guard silently under-refusing.
        expect(
          rotationFitsEdgeWindow(const CaptureConfig().maxRotationDeg),
          isTrue,
        );
      });

      test('a value past the window would not fit', () {
        // Sanity check on the predicate itself: it must be able to say no.
        expect(rotationFitsEdgeWindow(20), isFalse);
      });
    },
  );
}
