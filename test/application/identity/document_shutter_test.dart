import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/document_shutter.dart';

const _sharpnessThreshold = 100.0;
const _motionThreshold = 6.0;
const _steadyHoldMs = 800;
const _refusedHoldMs = 1500;

/// Feeds one frame to the shutter with the tunables fixed.
DocumentShutterState _step(
  DocumentShutterState prev, {
  required double sharpness,
  required double motion,
  required int nowMs,
  int steadyHoldMs = _steadyHoldMs,
}) => evaluateDocumentShutter(
  prev: prev,
  sharpness: sharpness,
  motion: motion,
  nowMs: nowMs,
  sharpnessThreshold: _sharpnessThreshold,
  motionThreshold: _motionThreshold,
  steadyHoldMs: steadyHoldMs,
  refusedHoldMs: _refusedHoldMs,
);

/// Arms the shutter the way a user does: one frame with real movement in it.
DocumentShutterState _armed({int atMs = 0}) => _step(
  const DocumentShutterState.initial(),
  sharpness: 500,
  motion: 40,
  nowMs: atMs,
);

/// Runs a still, sharp stretch from [fromMs] to [toMs] at [frameIntervalMs].
DocumentShutterState _holdStill(
  DocumentShutterState from, {
  required int fromMs,
  required int toMs,
  required int frameIntervalMs,
}) {
  var state = from;
  for (var t = fromMs; t <= toMs; t += frameIntervalMs) {
    state = _step(state, sharpness: 500, motion: 0, nowMs: t);
    if (state.shouldCapture) return state;
  }
  return state;
}

void main() {
  group('arming: nothing fires until the scene has moved', () {
    test('a still sharp scene from the very first frame never fires', () {
      var state = const DocumentShutterState.initial();
      // Ten seconds of a perfectly framed, perfectly still card that the user
      // never touched: exactly the verso arriving on the recto left in place.
      for (var t = 0; t <= 10000; t += 100) {
        state = _step(state, sharpness: 500, motion: 0, nowMs: t);
        expect(state.shouldCapture, isFalse);
        expect(state.reason, DocumentShutterReason.waitingForMotion);
        expect(state.armed, isFalse);
      }
    });

    test('movement arms the shutter, and it stays armed once still again', () {
      final armed = _armed();
      expect(armed.armed, isTrue);
      expect(armed.reason, DocumentShutterReason.moving);

      final still = _step(armed, sharpness: 500, motion: 0, nowMs: 100);
      expect(still.armed, isTrue);
      expect(still.reason, DocumentShutterReason.steadying);
    });

    test('an armed, still, sharp stretch does fire', () {
      final fired = _holdStill(
        _armed(),
        fromMs: 100,
        toMs: 2000,
        frameIntervalMs: 100,
      );
      expect(fired.shouldCapture, isTrue);
      expect(fired.reason, DocumentShutterReason.ready);
    });
  });

  group('the two signals', () {
    test('a blurred frame waits, however still it is', () {
      final state = _step(_armed(), sharpness: 10, motion: 0, nowMs: 100);
      expect(state.shouldCapture, isFalse);
      expect(state.reason, DocumentShutterReason.tooBlurred);
    });

    test('a sharp but moving frame waits', () {
      final state = _step(_armed(), sharpness: 500, motion: 40, nowMs: 100);
      expect(state.shouldCapture, isFalse);
      expect(state.reason, DocumentShutterReason.moving);
    });

    test('a hold shorter than the threshold waits, with partial progress', () {
      final state = _holdStill(
        _armed(),
        fromMs: 100,
        toMs: 500,
        frameIntervalMs: 100,
      );
      expect(state.shouldCapture, isFalse);
      expect(state.reason, DocumentShutterReason.steadying);
      expect(state.progress, greaterThan(0));
      expect(state.progress, lessThan(1));
    });

    test('progress grows while the scene stays still', () {
      var state = _armed();
      var last = 0.0;
      for (var t = 100; t < 800; t += 100) {
        state = _step(state, sharpness: 500, motion: 0, nowMs: t);
        expect(state.progress, greaterThanOrEqualTo(last));
        last = state.progress;
      }
      expect(last, greaterThan(0));
    });

    test('movement mid-hold sends progress back to zero', () {
      var state = _holdStill(
        _armed(),
        fromMs: 100,
        toMs: 600,
        frameIntervalMs: 100,
      );
      expect(state.progress, greaterThan(0));

      state = _step(state, sharpness: 500, motion: 40, nowMs: 700);
      expect(state.progress, 0);
      expect(state.steadySinceMs, isNull);

      // And the hold must start over, not resume where it left off.
      final resumed = _step(state, sharpness: 500, motion: 0, nowMs: 800);
      expect(resumed.progress, 0);
      expect(resumed.shouldCapture, isFalse);
    });

    test('a blurred frame mid-hold also restarts the hold', () {
      var state = _holdStill(
        _armed(),
        fromMs: 100,
        toMs: 600,
        frameIntervalMs: 100,
      );
      state = _step(state, sharpness: 10, motion: 0, nowMs: 700);
      expect(state.steadySinceMs, isNull);
    });
  });

  group('the hold is real time, not a frame count', () {
    test('it lasts the same duration at 10 fps as at 30 fps', () {
      // 30 fps: a frame every 33 ms.
      final fast = _holdStill(
        _armed(),
        fromMs: 33,
        toMs: 5000,
        frameIntervalMs: 33,
      );
      // 10 fps: a frame every 100 ms. Three times fewer frames, same wall clock.
      final slow = _holdStill(
        _armed(),
        fromMs: 100,
        toMs: 5000,
        frameIntervalMs: 100,
      );

      expect(fast.shouldCapture, isTrue);
      expect(slow.shouldCapture, isTrue);
      // Both fired within one frame interval of the 800 ms hold, not after a
      // fixed number of frames.
      expect(fast.steadySinceMs, isNotNull);
      expect(slow.steadySinceMs, isNotNull);
    });

    test('at 10 fps it has NOT fired before the hold has elapsed', () {
      final tooEarly = _holdStill(
        _armed(),
        fromMs: 100,
        toMs: 700,
        frameIntervalMs: 100,
      );
      expect(tooEarly.shouldCapture, isFalse);
    });
  });

  group('a refusal owns the screen for its hold', () {
    test('it survives many frames, not one', () {
      var state = const DocumentShutterState.refused();
      // The refusal is anchored on the FIRST frame after the resume, so a long
      // capture round trip cannot have expired it already.
      for (var t = 4000; t < 4000 + _refusedHoldMs; t += 100) {
        state = _step(state, sharpness: 500, motion: 0, nowMs: t);
        expect(state.reason, DocumentShutterReason.refused);
        expect(state.shouldCapture, isFalse);
      }
    });

    test('nothing fires during it, even on a perfect frame', () {
      var state = const DocumentShutterState.refused();
      for (var t = 0; t < _refusedHoldMs; t += 100) {
        state = _step(state, sharpness: 500, motion: 0, nowMs: t);
        expect(state.shouldCapture, isFalse);
      }
    });

    test('after it, the shutter is DISARMED: a new gesture is required', () {
      var state = const DocumentShutterState.refused();
      // Let the refusal hold expire on a still, sharp scene.
      for (var t = 0; t <= _refusedHoldMs + 200; t += 100) {
        state = _step(state, sharpness: 500, motion: 0, nowMs: t);
      }
      expect(state.reason, DocumentShutterReason.waitingForMotion);
      expect(state.armed, isFalse);

      // Even given all the time in the world, a still scene never fires again.
      for (var t = 2000; t <= 12000; t += 100) {
        state = _step(state, sharpness: 500, motion: 0, nowMs: t);
        expect(state.shouldCapture, isFalse);
      }
    });

    test(
      'an immediate re-fire is impossible however long the capture took',
      () {
        // The refusal is anchored on the first frame back, so whether the round
        // trip took 200 ms or 3 s, a full hold is still required afterwards.
        for (final resumeAtMs in [200, 3000, 30000]) {
          var state = const DocumentShutterState.refused();
          state = _step(state, sharpness: 500, motion: 0, nowMs: resumeAtMs);
          expect(state.reason, DocumentShutterReason.refused);
          expect(state.shouldCapture, isFalse);
        }
      },
    );
  });

  group('autoShutterEnabled', () {
    test('is on below the limit and off at it', () {
      expect(autoShutterEnabled(autoRejects: 0, rejectLimit: 3), isTrue);
      expect(autoShutterEnabled(autoRejects: 2, rejectLimit: 3), isTrue);
      expect(autoShutterEnabled(autoRejects: 3, rejectLimit: 3), isFalse);
      expect(autoShutterEnabled(autoRejects: 9, rejectLimit: 3), isFalse);
    });
  });

  group('offerManualShutter', () {
    test('is hidden while the automatic shutter still has attempts left', () {
      expect(
        offerManualShutter(fallbackDue: false, autoRejects: 0, rejectLimit: 3),
        isFalse,
      );
      expect(
        offerManualShutter(fallbackDue: false, autoRejects: 2, rejectLimit: 3),
        isFalse,
      );
    });

    test('the timer alone offers it, whatever the refusals', () {
      expect(
        offerManualShutter(fallbackDue: true, autoRejects: 0, rejectLimit: 3),
        isTrue,
      );
    });

    test('exhausting the automatic attempts offers it without the timer', () {
      expect(
        offerManualShutter(fallbackDue: false, autoRejects: 3, rejectLimit: 3),
        isTrue,
      );
    });
  });
}
