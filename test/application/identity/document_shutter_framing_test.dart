import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/document_shutter.dart';
import 'package:outalma_app/src/domain/identity/document_quad.dart';

/// The framing input to the shutter, and its grace fallback.
///
/// A new FILE rather than new cases in `document_shutter_test.dart`, so that not
/// one existing test line is touched: the additivity of this increment is a DoD
/// line proved by `git diff --numstat` showing zero deletions under `test/`.
///
/// The two anchors have deliberately different reach, and that asymmetry is the
/// whole correction this file guards:
///
/// - `badFramingSinceMs` is relayed by EVERY branch, so one hand tremor cannot
///   reset the grace clock and make "never blocking" a claim rather than a
///   behaviour;
/// - `steadySinceMs` is relayed by ONE branch only. It guards an uninterrupted
///   sharp-and-still stretch, and carrying it through `tooBlurred` or `moving`
///   would loosen that to "800 ms, tremors tolerated" on the DEFAULT path.
const double _sharp = 500;
const double _blurred = 10;
const double _sharpnessThreshold = 100;
const double _motionThreshold = 6;
const int _steadyHold = 800;
const int _grace = 4000;

DocumentShutterState _step(
  DocumentShutterState prev, {
  double sharpness = _sharp,
  double motion = 0,
  required int nowMs,
  DocumentFraming framing = DocumentFraming.unknown,
  int framingGraceMs = _grace,
}) {
  return evaluateDocumentShutter(
    prev: prev,
    sharpness: sharpness,
    motion: motion,
    nowMs: nowMs,
    sharpnessThreshold: _sharpnessThreshold,
    motionThreshold: _motionThreshold,
    steadyHoldMs: _steadyHold,
    refusedHoldMs: 1500,
    framing: framing,
    framingGraceMs: framingGraceMs,
  );
}

/// An armed shutter: the scene has moved once, which is the prerequisite the
/// whole screen is built on.
DocumentShutterState _armed() =>
    _step(const DocumentShutterState.initial(), motion: 40, nowMs: 0);

void main() {
  group('unknown framing reproduces the old behaviour', () {
    test('the hold runs and fires exactly as before', () {
      var state = _armed();
      state = _step(state, nowMs: 100);
      expect(state.reason, DocumentShutterReason.steadying);
      state = _step(state, nowMs: 900);
      expect(state.reason, DocumentShutterReason.ready);
      expect(state.shouldCapture, isTrue);
    });

    test('no grace anchor is ever set', () {
      var state = _armed();
      for (var t = 100; t <= 600; t += 100) {
        state = _step(state, nowMs: t);
        expect(state.badFramingSinceMs, isNull);
      }
    });
  });

  group('good framing changes nothing either', () {
    test('the hold is neither shortened nor lengthened', () {
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.good);
      expect(state.reason, DocumentShutterReason.steadying);
      // The anchor was set at 100, so the hold completes at 900 exactly, the
      // same frame as on the unknown path above. Neither sooner nor later.
      state = _step(state, nowMs: 899, framing: DocumentFraming.good);
      expect(state.shouldCapture, isFalse, reason: 'one millisecond short');
      state = _step(state, nowMs: 900, framing: DocumentFraming.good);
      expect(state.shouldCapture, isTrue);
      expect(state.badFramingSinceMs, isNull);
    });
  });

  group('a readable but wrong framing holds the shutter', () {
    test('too small does not fire, and says so', () {
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.tooSmall);
      expect(state.reason, DocumentShutterReason.tooSmall);
      expect(state.shouldCapture, isFalse);

      state = _step(state, nowMs: 1500, framing: DocumentFraming.tooSmall);
      expect(state.shouldCapture, isFalse, reason: 'well past the hold');
    });

    test('each wrong framing has its OWN reason', () {
      final cases = {
        DocumentFraming.none: DocumentShutterReason.noDocument,
        DocumentFraming.tooSmall: DocumentShutterReason.tooSmall,
        DocumentFraming.tooClose: DocumentShutterReason.tooClose,
      };
      cases.forEach((framing, reason) {
        final state = _step(_armed(), nowMs: 100, framing: framing);
        expect(state.reason, reason, reason: '$framing');
      });
    });

    test('the ring keeps filling on the grace', () {
      // A ring that jumped from nothing to full at expiry would say nothing to
      // someone who cannot read, and the ring is their main signal.
      var state = _step(_armed(), nowMs: 100, framing: DocumentFraming.none);
      final early = state.progress;
      state = _step(state, nowMs: 2100, framing: DocumentFraming.none);
      expect(state.progress, greaterThan(early));
      expect(state.progress, lessThan(1));
    });
  });

  group('the grace fallback', () {
    test('fires on the expiry frame itself', () {
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.none);
      expect(state.badFramingSinceMs, 100);

      for (var t = 200; t < 100 + _grace; t += 400) {
        state = _step(state, nowMs: t, framing: DocumentFraming.none);
        expect(state.shouldCapture, isFalse, reason: 'still inside the grace');
      }

      state = _step(state, nowMs: 100 + _grace, framing: DocumentFraming.none);
      expect(state.shouldCapture, isTrue);
      expect(state.reason, DocumentShutterReason.ready);
    });

    test('SURVIVES a blurred frame in the middle of the run', () {
      // The exact hole that made an earlier version of this rule inoperative:
      // the early returns dropped the anchor, so one tremor reset the clock and
      // the fallback never arrived. A card on a dark table stayed stuck.
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.none);
      state = _step(state, nowMs: 1000, framing: DocumentFraming.none);

      state = _step(
        state,
        sharpness: _blurred,
        nowMs: 1100,
        framing: DocumentFraming.none,
      );
      expect(state.reason, DocumentShutterReason.tooBlurred);
      expect(
        state.badFramingSinceMs,
        100,
        reason: 'the grace clock must NOT restart',
      );

      // And it still fires once the grace is up, counted from the original
      // anchor rather than from the tremor.
      state = _step(state, nowMs: 1200, framing: DocumentFraming.none);
      state = _step(
        state,
        nowMs: 100 + _grace + 900,
        framing: DocumentFraming.none,
      );
      expect(state.shouldCapture, isTrue);
    });

    test('survives a moving frame too', () {
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.none);
      state = _step(
        state,
        motion: 40,
        nowMs: 500,
        framing: DocumentFraming.none,
      );
      expect(state.reason, DocumentShutterReason.moving);
      expect(state.badFramingSinceMs, 100);
    });

    test('a good framing in between RESETS the grace clock', () {
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.none);
      expect(state.badFramingSinceMs, 100);

      state = _step(state, nowMs: 200, framing: DocumentFraming.good);
      expect(state.badFramingSinceMs, isNull);

      state = _step(state, nowMs: 300, framing: DocumentFraming.none);
      expect(state.badFramingSinceMs, 300, reason: 're-anchored, not resumed');
    });

    test('never bypasses the sharpness gate at expiry', () {
      // The fallback DOWNGRADES the framing; it does not license a blurred
      // shot. Sending a blurred still would be a silent drop in guarantee.
      var state = _armed();
      state = _step(state, nowMs: 100, framing: DocumentFraming.none);
      state = _step(
        state,
        sharpness: _blurred,
        nowMs: 100 + _grace,
        framing: DocumentFraming.none,
      );
      expect(state.shouldCapture, isFalse);
      expect(state.reason, DocumentShutterReason.tooBlurred);
    });

    test('never bypasses the arming gate', () {
      // A card left lying there must still never be photographed, whatever the
      // framing says: that is the trap the disarmed shutter exists to close.
      var state = const DocumentShutterState.initial();
      for (var t = 0; t <= _grace + 1000; t += 500) {
        state = _step(state, nowMs: t, framing: DocumentFraming.tooSmall);
        expect(state.shouldCapture, isFalse, reason: 'disarmed at $t');
      }
      expect(state.reason, DocumentShutterReason.waitingForMotion);
    });
  });

  group('the uninterrupted-hold guard is NOT loosened', () {
    test('a blurred frame still restarts the hold on the default path', () {
      // The mirror mistake: relaying steadySinceMs everywhere would turn
      // "800 ms without interruption" into "800 ms, tremors tolerated".
      var state = _armed();
      state = _step(state, nowMs: 100);
      state = _step(state, nowMs: 700);
      expect(state.progress, greaterThan(0));

      state = _step(state, sharpness: _blurred, nowMs: 750);
      expect(state.steadySinceMs, isNull);

      final resumed = _step(state, nowMs: 800);
      expect(resumed.shouldCapture, isFalse);
      expect(resumed.progress, lessThan(0.5), reason: 'the hold restarted');
    });

    test('a moving frame still restarts the hold', () {
      var state = _armed();
      state = _step(state, nowMs: 100);
      state = _step(state, nowMs: 700);
      state = _step(state, motion: 40, nowMs: 750);
      expect(state.steadySinceMs, isNull);
    });
  });
}
