/// The document shutter decision, pure and testable.
///
/// The document side of the journey guides providers who may not read: the
/// photo is taken on its own once the framing settles, so nothing has to be
/// read and no button has to be found. This file holds the whole decision, on
/// the same shape as `evaluateCaptureWindow` for the selfie: the screen only
/// obeys, so every branch is testable and every guard is mutable (T3).
///
/// Two signals decide, and both are needed. Sharpness alone is not stillness (a
/// moving hand can hold focus), and stillness alone is not a readable card.
///
/// The trap this file exists to close is the SECOND side. After the first shot
/// the card is still lying there, sharp and motionless, and the verso screen is
/// a brand new state with a brand new hold: left alone it would photograph the
/// recto nobody turned over, the readable-text gate would accept it (a recto
/// carries text), and the batch would ship two rectos. So the shutter starts
/// DISARMED and only arms once the scene has actually moved. An automatic
/// action that asks for no gesture must still require that a gesture happened.
library;

import '../../domain/identity/document_quad.dart';

/// Why the shutter is doing what it is doing. The screen renders an icon per
/// value, never colour alone (A3).
enum DocumentShutterReason {
  /// No frame analysed: the stream is stopped, so sharpness is UNKNOWN. Never
  /// "the last value we saw", which would judge a scene nobody is looking at.
  noFrame,

  /// Frames are arriving but the scene has not moved yet, so the shutter is
  /// still disarmed. On the verso this is the "turn the card over" state.
  waitingForMotion,

  tooBlurred,
  moving,

  /// Sharp and still: the hold is running and [DocumentShutterState.progress]
  /// fills the ring.
  steadying,

  /// The hold completed; the photo is being taken.
  ready,

  /// A photo was taken and refused downstream. Held for a while so a person who
  /// cannot read still sees that something happened and was not kept.
  refused,

  /// Sharp and still, but the contour detector sees no credible card. Includes
  /// a shape that is not a card's: that is the ABSENCE of a card, not a badly
  /// framed one.
  noDocument,

  /// A card, too far away to be read. "Come closer."
  tooSmall,

  /// A card, too close: it touches or overflows the frame. "Back off." Never
  /// confused with [tooSmall], because telling someone who fills the screen to
  /// come closer is exactly the kind of nonsense a person who cannot read has
  /// no way to recover from.
  tooClose,
}

/// Immutable shutter state, threaded frame to frame by [evaluateDocumentShutter].
class DocumentShutterState {
  const DocumentShutterState({
    this.armed = false,
    this.steadySinceMs,
    this.refusedSinceMs,
    this.reason = DocumentShutterReason.noFrame,
    this.progress = 0,
    this.shouldCapture = false,
    this.badFramingSinceMs,
  });

  /// The state a screen starts from, and returns to after every capture.
  const DocumentShutterState.initial() : this();

  /// The state a screen adopts after a refused shot: disarmed like a fresh
  /// start, so a new gesture and a whole new hold are required, and showing the
  /// refusal until [refusedSinceMs] is older than the hold.
  ///
  /// [refusedSinceMs] is deliberately left null here: it is anchored on the
  /// FIRST FRAME RECEIVED AFTER THE STREAM RESUMES, not on the moment of the
  /// refusal. A capture round trip (stop the stream, shoot, run text
  /// recognition) costs 500 to 1000 ms on the target hardware, so a hold
  /// measured from the refusal would already have expired by the time the
  /// preview comes back, and the refusal icon would flash for a single frame.
  const DocumentShutterState.refused()
    : this(reason: DocumentShutterReason.refused);

  /// Whether the scene has moved at least once since this screen was entered.
  final bool armed;

  /// When the current uninterrupted sharp-and-still stretch began.
  final int? steadySinceMs;

  /// When the refusal started being shown, anchored on the first frame after
  /// the stream resumed.
  final int? refusedSinceMs;

  final DocumentShutterReason reason;

  /// 0 to 1: how much of the hold has elapsed. Drives the ring.
  final double progress;

  /// True on the single transition where the screen must shoot.
  final bool shouldCapture;

  /// When the current UNINTERRUPTED run of bad framing began.
  ///
  /// The carrier of the grace clock, and it is relayed by EVERY branch. Without
  /// that a single blurred frame, one hand tremor, would reset it and the
  /// fallback would never fire, which would make "never blocking" a claim
  /// rather than a behaviour.
  ///
  /// It is emphatically NOT the same as [steadySinceMs], which is relayed by
  /// one branch only. That one guards an UNINTERRUPTED sharp-and-still stretch:
  /// carrying it through `tooBlurred` and `moving` would turn "800 ms without
  /// interruption" into "800 ms, tremors tolerated", on the default path, and
  /// two shipped tests hold it to the stricter meaning.
  final int? badFramingSinceMs;
}

/// Advances the shutter by one analysed frame.
///
/// [sharpness] and [motion] come from `ImageSharpness.laplacianVariance` and
/// `FrameMotion.meanAbsoluteDifference` over the same centred window. [nowMs] is
/// real elapsed time, never a frame count, so the hold lasts the same wall-clock
/// duration at 10 frames per second as at 30.
DocumentShutterState evaluateDocumentShutter({
  required DocumentShutterState prev,
  required double sharpness,
  required double motion,
  required int nowMs,
  required double sharpnessThreshold,
  required double motionThreshold,
  required int steadyHoldMs,
  required int refusedHoldMs,
  DocumentFraming framing = DocumentFraming.unknown,
  int framingGraceMs = 4000,
}) {
  // A refusal owns the screen for its hold, anchored on the first frame that
  // arrives after the resume. Nothing can fire during it.
  final moved = motion > motionThreshold;

  // The grace anchor, computed ONCE and relayed unchanged by every branch
  // below. One calculation rather than two competing rules: "every branch
  // relays it" and "good or unknown clears it" would contradict each other on a
  // frame that is well framed but blurred.
  //
  // It only starts once the scene has been TOUCHED, and that condition is not a
  // detail: the grace measures how long the provider has been struggling with
  // the framing, never how long a card sat on a table. Without it, a card left
  // too far away for the whole grace before anyone touches it would have its
  // clock already spent, and the first sharp-and-still stretch after the gesture
  // would shoot a too-small frame without ever having said "come closer".
  final badSince =
      (framing == DocumentFraming.good || framing == DocumentFraming.unknown)
      ? null
      : (prev.armed || moved)
      ? (prev.badFramingSinceMs ?? nowMs)
      : null;

  // The fallback, and it is what makes "never blocking" true rather than
  // declarative: once the bad framing has lasted its grace, the framing is
  // DOWNGRADED to unknown and the frame is read exactly as it was before this
  // feature existed. It never bypasses the sharpness or motion gates, so a
  // blurred frame at expiry is still refused.
  final graceExpired = badSince != null && nowMs - badSince >= framingGraceMs;
  final effective = graceExpired ? DocumentFraming.unknown : framing;

  if (prev.reason == DocumentShutterReason.refused) {
    final since = prev.refusedSinceMs ?? nowMs;
    if (nowMs - since < refusedHoldMs) {
      // Nothing fires during the hold, but movement still counts: someone who
      // is already picking the card back up should not have to move it twice.
      // The state starts disarmed, so a scene left untouched still never arms.
      return DocumentShutterState(
        armed: prev.armed || moved,
        refusedSinceMs: since,
        reason: DocumentShutterReason.refused,
        badFramingSinceMs: badSince,
      );
    }
    // The hold is over: read this frame normally, carrying whatever arming the
    // hold collected. A scene nobody touched is still disarmed.
  }

  final armed = prev.armed || moved;

  // Disarmed: the scene has not moved since this screen was entered, so what is
  // in frame is whatever was already there. Never shoot it.
  if (!armed) {
    return DocumentShutterState(
      reason: DocumentShutterReason.waitingForMotion,
      badFramingSinceMs: badSince,
    );
  }

  if (sharpness < sharpnessThreshold) {
    return DocumentShutterState(
      armed: true,
      reason: DocumentShutterReason.tooBlurred,
      badFramingSinceMs: badSince,
    );
  }

  if (moved) {
    return DocumentShutterState(
      armed: true,
      reason: DocumentShutterReason.moving,
      badFramingSinceMs: badSince,
    );
  }

  // Sharp and still, but the framing is readable and wrong. The hold is anchored
  // HERE, and this is the only branch that carries `steadySinceMs` forward,
  // which is legitimate precisely because this branch is by definition sharp
  // and still. The ring keeps filling on the grace, so a person who cannot read
  // still sees that something is running rather than a ring that jumps from
  // nothing to full at expiry.
  if (effective != DocumentFraming.unknown &&
      effective != DocumentFraming.good) {
    // Non-null by construction: reaching this branch means the framing is
    // neither good nor unknown AND the shutter is armed, which is exactly
    // when the anchor is set.
    final graceHeld = nowMs - badSince!;
    return DocumentShutterState(
      armed: true,
      steadySinceMs: prev.steadySinceMs ?? nowMs,
      badFramingSinceMs: badSince,
      reason: switch (effective) {
        DocumentFraming.tooSmall => DocumentShutterReason.tooSmall,
        DocumentFraming.tooClose => DocumentShutterReason.tooClose,
        _ => DocumentShutterReason.noDocument,
      },
      progress: (graceHeld / framingGraceMs).clamp(0.0, 1.0),
    );
  }

  final since = prev.steadySinceMs ?? nowMs;
  final held = nowMs - since;
  if (held >= steadyHoldMs) {
    return DocumentShutterState(
      armed: true,
      steadySinceMs: since,
      badFramingSinceMs: badSince,
      reason: DocumentShutterReason.ready,
      progress: 1,
      shouldCapture: true,
    );
  }

  return DocumentShutterState(
    armed: true,
    steadySinceMs: since,
    badFramingSinceMs: badSince,
    reason: DocumentShutterReason.steadying,
    progress: held / steadyHoldMs,
  );
}

/// Whether the automatic shutter is still allowed to fire.
///
/// Past [rejectLimit] consecutive refusals the loop gives up rather than
/// burning shots on a card it cannot read, and the manual button takes over.
bool autoShutterEnabled({required int autoRejects, required int rejectLimit}) =>
    autoRejects < rejectLimit;

/// Whether the manual shutter button is shown.
///
/// [fallbackDue] is set by a one-shot timer owned by the screen, NOT by the
/// frame clock. It has to be independent of the frames: an image-fed clock does
/// not advance when nothing arrives, so a dead stream would leave the user with
/// no command at all. And it cannot key off "sharpness is unknown" either,
/// because before the first frame "the stream has not delivered yet" and "the
/// stream is dead" are the same observable state, which would show the button
/// from the first millisecond of every page and then hide it again.
bool offerManualShutter({
  required bool fallbackDue,
  required int autoRejects,
  required int rejectLimit,
}) => fallbackDue || autoRejects >= rejectLimit;
