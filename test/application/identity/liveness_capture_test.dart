import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/liveness_capture.dart';

void main() {
  group('evaluateCaptureWindow', () {
    test('waits while the machine has not reached ready', () {
      expect(
        evaluateCaptureWindow(readyAtMs: null, nowMs: 500, lastFaceCount: 1),
        LivenessCaptureAction.wait,
      );
    });

    test('captures when frontal, single face, within the window', () {
      expect(
        evaluateCaptureWindow(readyAtMs: 1000, nowMs: 1000, lastFaceCount: 1),
        LivenessCaptureAction.capture,
      );
      expect(
        evaluateCaptureWindow(readyAtMs: 1000, nowMs: 1900, lastFaceCount: 1),
        LivenessCaptureAction.capture,
      );
    });

    // Mutated guard (T3): a long gap between the frontal return and the shutter
    // is where a printed photo could be swapped in, so it is abandoned.
    test('abandons once the shutter window has closed', () {
      expect(
        evaluateCaptureWindow(readyAtMs: 1000, nowMs: 2001, lastFaceCount: 1),
        LivenessCaptureAction.abandon,
      );
    });

    test('abandons when the framing frame is not a single face', () {
      expect(
        evaluateCaptureWindow(readyAtMs: 1000, nowMs: 1100, lastFaceCount: 0),
        LivenessCaptureAction.abandon,
      );
      expect(
        evaluateCaptureWindow(readyAtMs: 1000, nowMs: 1100, lastFaceCount: 2),
        LivenessCaptureAction.abandon,
      );
    });

    test('honours a custom window bound', () {
      expect(
        evaluateCaptureWindow(
          readyAtMs: 0,
          nowMs: 400,
          lastFaceCount: 1,
          maxDelayMs: 300,
        ),
        LivenessCaptureAction.abandon,
      );
    });
  });
}
