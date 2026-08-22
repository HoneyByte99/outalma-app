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
class CaptureConfig {
  const CaptureConfig({
    this.rectoSharpnessThreshold = 120,
    this.versoSharpnessThreshold = 80,

    /// After this many consecutive blur refusals on the SAME still, offer
    /// "send anyway, a human will review it" (AC-C34). Never applies to the
    /// liveness challenge, whose bypass would be an invisible drop in guarantee.
    this.blurOverrideAfter = 2,
  }) : assert(
         rectoSharpnessThreshold > versoSharpnessThreshold,
         'the recto must be strictly harder than the verso (AC-C06)',
       );

  final double rectoSharpnessThreshold;
  final double versoSharpnessThreshold;
  final int blurOverrideAfter;

  double sharpnessThresholdFor(DocumentSide side) => side == DocumentSide.recto
      ? rectoSharpnessThreshold
      : versoSharpnessThreshold;
}

/// The lens each side uses. Both document sides use the back camera; the selfie
/// uses the front one.
CameraLensDirection lensForSide(DocumentSide side) => CameraLensDirection.back;
