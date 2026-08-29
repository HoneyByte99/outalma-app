import 'capture_source.dart';

/// Which side of the ID card is being captured. Drives the framing hint, the
/// instruction copy and the sharpness threshold.
enum DocumentSide { recto, verso }

/// Tunable capture parameters (archi 5.3, AC-C06).
///
/// The two sharpness thresholds are PLACEHOLDERS: their absolute values are
/// calibrated on the real-phone pass (Q2) and written back here afterwards. The
/// tests only prove the mechanism and the ordering, the recto threshold being
/// STRICTLY higher than the verso's, never the exact numbers (AC-C06). The
/// ordering is a mutated guard (T3): lowering the recto to the verso's value
/// must turn a test red.
///
/// [analysisCenterFraction] changes what those two numbers MEAN, since the
/// variance is no longer read over the whole plane: they must be re-measured on
/// the phone pass and written back here. [motionThreshold] is a placeholder on
/// the same footing.
class CaptureConfig {
  const CaptureConfig({
    this.rectoSharpnessThreshold = 120,
    this.versoSharpnessThreshold = 80,

    /// After this many consecutive blur refusals on the SAME still, offer
    /// "send anyway, a human will review it" (AC-C34). Never applies to the
    /// liveness challenge, whose bypass would be an invisible drop in guarantee.
    this.blurOverrideAfter = 2,

    /// Mean absolute luminance difference between two frame signatures, above
    /// which the scene counts as moving. Serves two roles: above it the shutter
    /// ARMS (the user handled the card), below it the framing counts as still.
    /// If the phone pass shows hand tremor colliding with the flip gesture,
    /// split this into two thresholds rather than raising the single value,
    /// which would degrade one of the two roles.
    this.motionThreshold = 6,

    /// How long the framing must stay sharp and still before the shutter fires.
    this.steadyHoldMs = 800,

    /// How long a refused shot stays on screen. Measured from the first frame
    /// after the stream resumes, so it survives the capture round trip.
    this.refusedHoldMs = 1500,

    /// How long the automatic shutter is given before the manual button is
    /// offered as a fallback, so nobody is ever stranded.
    this.manualFallbackAfterMs = 10000,

    /// Consecutive automatic refusals after which the loop stops trying and
    /// hands over to the manual button.
    this.autoRejectLimit = 3,

    /// Analyse one frame in N. The hold is long enough that ~10 Hz decides just
    /// as well as 30, at a third of the cost on the target hardware.
    this.analyzeEveryNthFrame = 3,

    /// Fraction of each dimension the two measures read, centred. Drops the
    /// periphery, where nobody holds a card: without it a sharp background
    /// behind a blurred card passes the gate, and someone moving in the
    /// background blocks the shutter for good.
    this.analysisCenterFraction = 0.7,
  }) : assert(
         rectoSharpnessThreshold > versoSharpnessThreshold,
         'the recto must be strictly harder than the verso (AC-C06)',
       ),
       assert(motionThreshold >= 0, 'a motion threshold cannot be negative'),
       assert(steadyHoldMs > 0, 'a hold of zero would fire on the first frame'),
       assert(refusedHoldMs > 0, 'a refusal must stay visible'),
       assert(autoRejectLimit >= 1, 'at least one automatic attempt'),
       assert(analyzeEveryNthFrame >= 1, 'at least one frame in one'),
       assert(
         analysisCenterFraction > 0 && analysisCenterFraction <= 1,
         'the analysis window is a fraction of the frame',
       );

  final double rectoSharpnessThreshold;
  final double versoSharpnessThreshold;
  final int blurOverrideAfter;
  final double motionThreshold;
  final int steadyHoldMs;
  final int refusedHoldMs;
  final int manualFallbackAfterMs;
  final int autoRejectLimit;
  final int analyzeEveryNthFrame;
  final double analysisCenterFraction;

  double sharpnessThresholdFor(DocumentSide side) => side == DocumentSide.recto
      ? rectoSharpnessThreshold
      : versoSharpnessThreshold;
}

/// The lens each side uses. Both document sides use the back camera; the selfie
/// uses the front one.
CameraLensDirection lensForSide(DocumentSide side) => CameraLensDirection.back;
