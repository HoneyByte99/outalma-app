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
  });
}
