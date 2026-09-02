/// The selfie shutter decision, pure and testable (archi 5.3, AC-C07).
///
/// The default sequence does NOT shoot while the image stream is running: on
/// entry-level Android that concurrency depends on the device's hardware level
/// and cannot be assumed (verified 2026-08-22 against camera_android_camerax).
/// So once the liveness machine reaches `ready` (frontal again after a proven
/// turn), the screen stops the stream and shoots within a bounded delay. Beyond
/// that delay the still is abandoned and the challenge restarts, because a long
/// gap between the frontal return and the shutter is exactly where a printed
/// photo could be swapped in.
library;

/// The bounded delay between reaching `ready` and the shutter (archi 5.3 step 6).
const int kLivenessShutterWindowMs = 1000;

/// What the selfie screen should do at [nowMs], given the liveness window.
enum LivenessCaptureAction {
  /// Not ready to shoot yet: keep streaming.
  wait,

  /// Fire the shutter now: frontal, single face, within the window.
  capture,

  /// The window closed or the frame is no longer a single face: drop this
  /// attempt and restart the challenge (AC-C08).
  abandon,
}

/// Decides the shutter action.
///
/// [readyAtMs] is when the liveness machine first reached `ready` (null while it
/// has not). [lastFaceCount] is the face count on the frames framing the shot:
/// the single-face assertion of archi 5.3 step 5. [maxDelayMs] is the window.
LivenessCaptureAction evaluateCaptureWindow({
  required int? readyAtMs,
  required int nowMs,
  required int lastFaceCount,
  int maxDelayMs = kLivenessShutterWindowMs,
}) {
  if (readyAtMs == null) return LivenessCaptureAction.wait;

  // The window closed: a slow shutter or a stalled pipeline. Restart rather
  // than shoot a stale frame whose liveness is no longer fresh.
  if (nowMs - readyAtMs > maxDelayMs) return LivenessCaptureAction.abandon;

  // Exactly one face must frame the shot; zero or several breaks the single
  // subject guarantee.
  if (lastFaceCount != 1) return LivenessCaptureAction.abandon;

  return LivenessCaptureAction.capture;
}
