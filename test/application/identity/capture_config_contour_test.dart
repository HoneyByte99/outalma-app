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
    test('both contour flags are OFF', () {
      // Nothing about the capture screen may change until the real-phone pass
      // has calibrated the detection thresholds. Turning either of these on by
      // default would ship an uncalibrated threshold onto the automatic path.
      const config = CaptureConfig();
      expect(config.contourOverlayEnabled, isFalse);
      expect(config.contourFramingEnabled, isFalse);
    });

    test('no contour work is needed, so no grid is built', () {
      // "Inert" has to hold in milliseconds too. If the grid were built anyway,
      // the P1 and P5 budget lines would move while the feature is supposedly
      // switched off, and the phone pass would measure the wrong baseline.
      expect(const CaptureConfig().contourWorkNeeded, isFalse);
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
