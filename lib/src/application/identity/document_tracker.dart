/// Smooths the detected outline across frames, and decides when to show it.
///
/// A raw per-frame quad jitters, and the jitter is not cosmetic here: the people
/// this screen was rebuilt for do not read, so the contour IS the instruction. A
/// flickering contour is the worst possible signal for them, which is the same
/// argument that already settled when the manual shutter button may appear.
///
/// So two mechanisms, both stateless in the same way `evaluateDocumentShutter`
/// is: an immutable state threaded frame to frame, so every branch is reachable
/// from a test and every guard can be mutated.
///
/// - **Exponential smoothing** of the four corners, so the outline follows the
///   card instead of vibrating on it.
/// - **Hysteresis**: [acquireFrames] consecutive detections before it appears,
///   [loseFrames] consecutive misses before it goes. Asymmetric on purpose,
///   losing more slowly than it acquires, because a single dropped frame in the
///   middle of a steady hold must not blank the screen.
///
/// This lives in the same slice as the painter, not with the shutter wiring. A
/// slice that drew an unsmoothed contour would ship exactly the flicker the file
/// exists to prevent.
library;

import '../../domain/identity/document_edge_detector.dart';
import '../../domain/identity/document_quad.dart';

/// Immutable tracker state, threaded frame to frame by [trackDocument].
class DocumentTrackState {
  const DocumentTrackState({
    this.quad,
    this.framing = DocumentFraming.unknown,
    this.hits = 0,
    this.misses = 0,
    this.visible = false,
  });

  /// The state a screen starts from, and returns to after every capture.
  const DocumentTrackState.initial() : this();

  /// The smoothed outline, or null while nothing is being tracked. Non-null does
  /// not mean drawable: read [visible] for that.
  final DocumentQuad? quad;

  /// The framing the screen should speak about. Carried here rather than read
  /// straight off the observation so it stays in step with what is drawn.
  final DocumentFraming framing;

  /// Consecutive frames with a usable quad.
  final int hits;

  /// Consecutive frames without one.
  final int misses;

  /// Whether the contour has earned its place on screen.
  final bool visible;
}

/// Advances the tracker by one observation.
///
/// [smoothing] is the weight given to the NEW corner position, so 1 means no
/// smoothing at all and a small value means a heavy, slow outline. Clamped, so a
/// mis-set config cannot make the outline diverge.
DocumentTrackState trackDocument({
  required DocumentTrackState prev,
  required DocumentEdgeObservation observation,
  required double smoothing,
  required int acquireFrames,
  required int loseFrames,
}) {
  if (acquireFrames < 1) {
    throw ArgumentError.value(
      acquireFrames,
      'acquireFrames',
      'must be at least 1',
    );
  }
  if (loseFrames < 1) {
    throw ArgumentError.value(loseFrames, 'loseFrames', 'must be at least 1');
  }

  final alpha = smoothing.clamp(0.05, 1.0);
  final incoming = observation.quad;

  if (incoming == null) {
    final misses = prev.misses + 1;
    // The outline is kept while the misses are still being tolerated, so a
    // single dropped frame does not blank it. Only once the run is long enough
    // is it dropped, along with the quad it was drawing.
    final lost = misses >= loseFrames;
    return DocumentTrackState(
      quad: lost ? null : prev.quad,
      framing: observation.framing,
      hits: 0,
      misses: misses,
      visible: lost ? false : prev.visible,
    );
  }

  final previous = prev.quad;
  final smoothed = previous == null
      ? incoming
      : DocumentQuad(
          topLeft: _lerp(previous.topLeft, incoming.topLeft, alpha),
          topRight: _lerp(previous.topRight, incoming.topRight, alpha),
          bottomRight: _lerp(previous.bottomRight, incoming.bottomRight, alpha),
          bottomLeft: _lerp(previous.bottomLeft, incoming.bottomLeft, alpha),
        );

  final hits = prev.hits + 1;
  return DocumentTrackState(
    quad: smoothed,
    framing: observation.framing,
    hits: hits,
    misses: 0,
    // Once visible it stays visible until the misses say otherwise: re-earning
    // the acquisition run on every frame would flicker at the threshold.
    visible: prev.visible || hits >= acquireFrames,
  );
}

NormPoint _lerp(NormPoint from, NormPoint to, double alpha) =>
    (x: from.x + (to.x - from.x) * alpha, y: from.y + (to.y - from.y) * alpha);
