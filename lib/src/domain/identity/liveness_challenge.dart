/// Light liveness challenge as a pure state machine (archi 5.3, AC-C07/C08).
///
/// The selfie step must resist a printed photo and a photo shown on a screen,
/// but NOT a replayed video: passive anti-spoofing is out of product scope
/// (AC-C07). A still image cannot turn its head, so a single "turn your head,
/// then face the lens again" gesture is enough to reject both stills.
///
/// The gesture ends FACING the lens, never in profile (archi 5.3): the human
/// reviewer compares two frontal faces, so capturing at the turn would hand
/// them the hardest possible image. Crossing the yaw threshold proves liveness;
/// the frontal return produces the usable frame.
///
/// The machine is fed frames of (faceCount, yawAngleDeg, timestampMs) and is
/// pure: [reduce] is a free function with no camera and no clock, so every
/// path is testable and every guard mutable (T3). A thin [LivenessChallenge]
/// wrapper holds the current snapshot for the capture screen.
library;

enum LivenessState {
  /// No single face detected yet (zero faces, or face lost mid-challenge).
  waitingFace,

  /// More than one face in frame: ambiguous, cannot attribute the gesture.
  multipleFaces,

  /// One face, frontal, waiting for the head to turn past the yaw threshold.
  turnHead,

  /// The turn was seen; waiting for the head to come back to frontal.
  returnToFront,

  /// Frontal again after a valid turn: the capture window is open.
  ready,

  /// The challenge took too long and must be restarted (AC-C08).
  expired,
}

/// One camera observation. [yawAngleDeg] is the head Euler Y angle reported by
/// the face detector; its sign is the turn direction and only its magnitude
/// matters here.
class LivenessFrame {
  const LivenessFrame({
    required this.faceCount,
    required this.yawAngleDeg,
    required this.timestampMs,
  });

  final int faceCount;
  final double yawAngleDeg;
  final int timestampMs;
}

/// Tunable thresholds. Defaults sit in the task's 20-30 degree band for a light
/// challenge; they are parameters so the real-phone pass can adjust them and so
/// the ordering (turn strictly harder than the frontal return) is mutable.
class LivenessConfig {
  const LivenessConfig({
    this.turnThresholdDeg = 25,
    this.frontalThresholdDeg = 10,
    this.timeoutMs = 15000,
  }) : assert(
         turnThresholdDeg > frontalThresholdDeg,
         'the turn must be strictly harder than the frontal return',
       );

  final double turnThresholdDeg;
  final double frontalThresholdDeg;
  final int timeoutMs;
}

/// Immutable machine state. [rotationSeen] latches once the head has turned far
/// enough, so a wobble back and forth cannot un-prove the liveness. [startedAtMs]
/// is the first observed timestamp, the origin of the timeout.
class LivenessSnapshot {
  const LivenessSnapshot({
    this.state = LivenessState.waitingFace,
    this.rotationSeen = false,
    this.startedAtMs,
  });

  final LivenessState state;
  final bool rotationSeen;
  final int? startedAtMs;

  bool get isReady => state == LivenessState.ready;
  bool get isExpired => state == LivenessState.expired;
}

/// Pure transition. Given the previous snapshot and a new frame, returns the
/// next snapshot. No side effects, no globals.
LivenessSnapshot reduce(
  LivenessSnapshot prev,
  LivenessFrame frame,
  LivenessConfig config,
) {
  // Once ready, the capture window stays open regardless of later frames: the
  // screen decides when to fire the shutter, within its own short tolerance.
  if (prev.state == LivenessState.ready) return prev;

  final startedAtMs = prev.startedAtMs ?? frame.timestampMs;

  // Expiry is sticky until reset. It is checked before the face logic so a
  // stalled challenge cannot linger in turnHead forever.
  if (frame.timestampMs - startedAtMs > config.timeoutMs) {
    return LivenessSnapshot(
      state: LivenessState.expired,
      rotationSeen: prev.rotationSeen,
      startedAtMs: startedAtMs,
    );
  }
  if (prev.state == LivenessState.expired) return prev;

  if (frame.faceCount == 0) {
    return LivenessSnapshot(
      state: LivenessState.waitingFace,
      rotationSeen: prev.rotationSeen,
      startedAtMs: startedAtMs,
    );
  }
  if (frame.faceCount > 1) {
    return LivenessSnapshot(
      state: LivenessState.multipleFaces,
      rotationSeen: prev.rotationSeen,
      startedAtMs: startedAtMs,
    );
  }

  final magnitude = frame.yawAngleDeg.abs();
  if (!prev.rotationSeen) {
    if (magnitude >= config.turnThresholdDeg) {
      // Turn latched: now ask for the frontal return.
      return LivenessSnapshot(
        state: LivenessState.returnToFront,
        rotationSeen: true,
        startedAtMs: startedAtMs,
      );
    }
    return LivenessSnapshot(
      state: LivenessState.turnHead,
      rotationSeen: false,
      startedAtMs: startedAtMs,
    );
  }

  // Rotation already proven: capture opens as soon as the face is frontal.
  if (magnitude <= config.frontalThresholdDeg) {
    return LivenessSnapshot(
      state: LivenessState.ready,
      rotationSeen: true,
      startedAtMs: startedAtMs,
    );
  }
  return LivenessSnapshot(
    state: LivenessState.returnToFront,
    rotationSeen: true,
    startedAtMs: startedAtMs,
  );
}

/// Thin stateful wrapper over [reduce] for the capture screen. Holds the
/// current [snapshot]; [offer] advances it; [reset] restarts the challenge for
/// a retry (AC-C08).
class LivenessChallenge {
  LivenessChallenge({LivenessConfig config = const LivenessConfig()})
    : _config = config;

  final LivenessConfig _config;
  LivenessSnapshot _snapshot = const LivenessSnapshot();

  LivenessSnapshot get snapshot => _snapshot;
  LivenessState get state => _snapshot.state;

  LivenessSnapshot offer(LivenessFrame frame) {
    _snapshot = reduce(_snapshot, frame, _config);
    return _snapshot;
  }

  void reset() {
    _snapshot = const LivenessSnapshot();
  }
}
