import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/capture_config.dart';

void main() {
  group('CaptureConfig', () {
    test('the recto threshold is strictly harder than the verso (AC-C06)', () {
      const config = CaptureConfig();
      expect(
        config.sharpnessThresholdFor(DocumentSide.recto),
        greaterThan(config.sharpnessThresholdFor(DocumentSide.verso)),
      );
    });

    // Mutated guard (T3): equalising the two thresholds must turn a test red.
    test('rejects a config where recto is not harder than verso', () {
      expect(
        () => CaptureConfig(
          rectoSharpnessThreshold: 80,
          versoSharpnessThreshold: 80,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => CaptureConfig(
          rectoSharpnessThreshold: 50,
          versoSharpnessThreshold: 80,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the automatic shutter tunables have usable defaults', () {
      const config = CaptureConfig();
      expect(config.steadyHoldMs, greaterThan(0));
      expect(config.refusedHoldMs, greaterThan(0));
      expect(config.autoRejectLimit, greaterThanOrEqualTo(1));
      expect(config.analyzeEveryNthFrame, greaterThanOrEqualTo(1));
      expect(config.analysisCenterFraction, inExclusiveRange(0, 1.0001));
    });

    test('rejects a hold of zero, which would fire on the first frame', () {
      expect(
        () => CaptureConfig(steadyHoldMs: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a refusal that would never be seen', () {
      expect(
        () => CaptureConfig(refusedHoldMs: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a negative motion threshold', () {
      expect(
        () => CaptureConfig(motionThreshold: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a limit that would allow no automatic attempt', () {
      expect(
        () => CaptureConfig(autoRejectLimit: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects an analysis cadence that would analyse nothing', () {
      expect(
        () => CaptureConfig(analyzeEveryNthFrame: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects an analysis window outside the frame', () {
      expect(
        () => CaptureConfig(analysisCenterFraction: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => CaptureConfig(analysisCenterFraction: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
