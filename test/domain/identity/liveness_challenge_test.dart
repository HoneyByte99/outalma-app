import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/liveness_challenge.dart';

LivenessFrame _f(int faces, double yaw, int t) =>
    LivenessFrame(faceCount: faces, yawAngleDeg: yaw, timestampMs: t);

void main() {
  const config = LivenessConfig(); // turn 25, frontal 10, timeout 15000

  group('LivenessChallenge happy path', () {
    test('face, turn past threshold, return to frontal, then ready', () {
      final c = LivenessChallenge(config: config);
      expect(c.offer(_f(1, 0, 0)).state, LivenessState.turnHead);
      // Not enough turn yet.
      expect(c.offer(_f(1, 15, 100)).state, LivenessState.turnHead);
      // Turn latched.
      expect(c.offer(_f(1, 30, 200)).state, LivenessState.returnToFront);
      // Still turned, waiting for the return.
      expect(c.offer(_f(1, 22, 300)).state, LivenessState.returnToFront);
      // Frontal again -> capture window open.
      expect(c.offer(_f(1, 5, 400)).state, LivenessState.ready);
    });

    test('capture is at the frontal return, not at the turn', () {
      // Crossing the threshold must NOT be the capture point (archi 5.3): the
      // ready state only appears once the face is frontal again.
      final c = LivenessChallenge(config: config);
      c.offer(_f(1, 0, 0));
      final atTurn = c.offer(_f(1, 40, 100));
      expect(atTurn.state, isNot(LivenessState.ready));
      expect(atTurn.state, LivenessState.returnToFront);
    });

    test('the turn latches: a wobble back cannot un-prove liveness', () {
      final c = LivenessChallenge(config: config);
      c.offer(_f(1, 0, 0));
      c.offer(_f(1, 30, 100)); // latched
      // Even if a later frame is below the turn threshold but not yet frontal,
      // we are waiting for the return, never back to turnHead.
      expect(c.offer(_f(1, 18, 200)).state, LivenessState.returnToFront);
    });
  });

  group('LivenessChallenge interruptions', () {
    test('a lost face drops back to waitingFace, keeping the latch', () {
      final c = LivenessChallenge(config: config);
      c.offer(_f(1, 30, 100)); // latched, returnToFront
      final lost = c.offer(_f(0, 0, 200));
      expect(lost.state, LivenessState.waitingFace);
      expect(lost.rotationSeen, isTrue);
      // The face returns frontal -> ready, without re-doing the turn.
      expect(c.offer(_f(1, 4, 300)).state, LivenessState.ready);
    });

    test('more than one face is rejected as ambiguous', () {
      final c = LivenessChallenge(config: config);
      expect(c.offer(_f(2, 0, 0)).state, LivenessState.multipleFaces);
    });

    test('taking too long expires the challenge', () {
      final c = LivenessChallenge(config: config);
      c.offer(_f(1, 0, 0));
      expect(c.offer(_f(1, 5, 15001)).state, LivenessState.expired);
    });

    test('expired is sticky until reset, then the flow restarts', () {
      final c = LivenessChallenge(config: config);
      c.offer(_f(1, 0, 0));
      c.offer(_f(1, 5, 20000)); // expired
      expect(c.offer(_f(1, 30, 20100)).state, LivenessState.expired);
      c.reset();
      expect(c.offer(_f(1, 0, 21000)).state, LivenessState.turnHead);
    });

    test('once ready the capture window stays open', () {
      final c = LivenessChallenge(config: config);
      c.offer(_f(1, 0, 0));
      c.offer(_f(1, 30, 100));
      c.offer(_f(1, 2, 200)); // ready
      expect(c.offer(_f(0, 0, 300)).state, LivenessState.ready);
    });
  });

  group('LivenessChallenge accessors', () {
    test(
      'exposes the current snapshot and state, with ready/expired helpers',
      () {
        final c = LivenessChallenge(config: config);
        c.offer(_f(1, 0, 0));
        expect(c.state, LivenessState.turnHead);
        expect(c.snapshot.state, LivenessState.turnHead);
        expect(c.snapshot.isReady, isFalse);
        expect(c.snapshot.isExpired, isFalse);

        c.offer(_f(1, 30, 100));
        final ready = c.offer(_f(1, 2, 200));
        expect(ready.isReady, isTrue);

        c.reset();
        c.offer(_f(1, 0, 300));
        final expired = c.offer(_f(1, 0, 300 + config.timeoutMs + 1));
        expect(expired.isExpired, isTrue);
      },
    );
  });

  group('LivenessConfig', () {
    test('rejects a frontal threshold that is not strictly easier', () {
      expect(
        () => LivenessConfig(turnThresholdDeg: 10, frontalThresholdDeg: 10),
        throwsA(isA<AssertionError>()),
      );
    });

    test('respects a custom, tighter turn threshold', () {
      const strict = LivenessConfig(
        turnThresholdDeg: 30,
        frontalThresholdDeg: 8,
      );
      final c = LivenessChallenge(config: strict);
      c.offer(_f(1, 0, 0));
      // 25 degrees clears the default but not this stricter config.
      expect(c.offer(_f(1, 25, 100)).state, LivenessState.turnHead);
      expect(c.offer(_f(1, 31, 200)).state, LivenessState.returnToFront);
    });
  });
}
