import 'dart:math' as math;

import '../../domain/identity/document_edge_detector.dart'
    show edgeWindowFraction, idCardAspect;
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

    // --- Contour detection. Both flags ship FALSE, so the increment lands
    // inert: no contour drawn and no shutter behaviour changed. They are turned
    // on, in this order, at the end of the real-phone pass that calibrates the
    // thresholds below. Both are mutated guards (T3).

    /// When false the contour is not drawn, AND the detector is not even run,
    /// so the per-frame cost does not change either.
    ///
    /// Needed separately from [contourFramingEnabled]: [edgeThreshold] and
    /// [minEdgeSupport] decide whether a contour appears at all, so with an
    /// uncalibrated threshold the contour would be permanently absent or
    /// flickering, and a flickering contour is the worst possible signal for
    /// someone who cannot read.
    this.contourOverlayEnabled = false,

    /// When false the shutter is handed [DocumentFraming.unknown] whatever the
    /// detector saw, so its behaviour is bit for bit what it was before this
    /// feature existed.
    this.contourFramingEnabled = false,

    /// Long side of the detection grid, in cells. The short side is DERIVED from
    /// the frame so cells stay near-square: a fixed pair would be 3x anisotropic
    /// on a portrait plane, and the projection profiles would mean nothing.
    this.contourGridLongSide = 96,

    /// Mean |gradient| per cell above which a projection profile peak counts as
    /// a border. PLACEHOLDER, calibrated on the phone pass.
    this.edgeThreshold = 40,

    /// Fraction of a border's sampled points that must carry real gradient.
    this.minEdgeSupport = 0.6,

    /// Fraction of the plane's area below which the card is too far away.
    ///
    /// 0.18 and not 0.25: the PAINTED template covers about 0.25 of the surface
    /// (it is 0.86 of an ID-1 box, so 1.36:1, a pre-existing defect kept out of
    /// this ticket), so a card framed exactly inside it would sit right on the
    /// boundary. There is deliberately no upper area threshold: an ID-1 card
    /// cannot physically cover more than about 0.355 of the plane, so "too
    /// close" is decided geometrically instead.
    this.minFill = 0.18,

    /// Relative tolerance on the ID-1 ratio, measured long-over-short in plane
    /// pixels so it is independent of which way the card lies in the plane.
    this.aspectTolerance = 0.25,

    /// Supported in-plane rotation. Past it the detector returns `unknown` with
    /// NO quad: the projection profiles have no peak left to find there, so a
    /// returned outline would be a WRONG one. The template stays as the only
    /// guidance beyond this angle (Amath's call, 2026-09-02). Kept in sync with
    /// [edgeWindowFraction] by [rotationFitsEdgeWindow] and the test that calls
    /// it: the local-fit window must stay wide enough to measure a tilt this
    /// large on the card's long side, or the refusal guard silently stops
    /// firing.
    this.maxRotationDeg = 10,

    /// Weight given to the newest corner position. Low means a heavy, slow
    /// outline; 1 means no smoothing.
    this.contourSmoothing = 0.3,

    /// Consecutive detections before the contour appears.
    this.acquireFrames = 3,

    /// Consecutive misses before it goes. Deliberately larger than
    /// [acquireFrames]: losing slower than acquiring is what stops a single
    /// dropped frame from blanking the screen.
    this.loseFrames = 5,

    /// How long a readable-but-wrong framing may hold the shutter before the
    /// framing is DOWNGRADED to unknown and the photo is taken anyway.
    ///
    /// This is what makes "the contour never blocks anyone" true rather than
    /// declarative: a card on a dark table, where no contour can be found, is
    /// still photographed. A mutated guard (T3).
    this.framingGraceMs = 4000,
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
       ),
       assert(
         contourGridLongSide >= 12,
         'a grid under 12 cells leaves no room for a Sobel and a peak',
       ),
       assert(edgeThreshold >= 0, 'a gradient threshold cannot be negative'),
       assert(
         minEdgeSupport > 0 && minEdgeSupport <= 1,
         'edge support is a fraction',
       ),
       assert(minFill > 0 && minFill < 1, 'fill is a fraction of the plane'),
       assert(aspectTolerance > 0, 'a tolerance of zero accepts nothing'),
       assert(
         maxRotationDeg > 0 && maxRotationDeg < 45,
         'past 45 degrees there is no nearest axis',
       ),
       assert(
         contourSmoothing > 0 && contourSmoothing <= 1,
         'smoothing is a weight on the new position',
       ),
       assert(acquireFrames >= 1, 'at least one detection to appear'),
       assert(loseFrames >= 1, 'at least one miss to disappear'),
       assert(
         framingGraceMs > 0,
         'a grace of zero would never let a bad framing be overridden',
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

  final bool contourOverlayEnabled;
  final bool contourFramingEnabled;
  final int contourGridLongSide;
  final double edgeThreshold;
  final double minEdgeSupport;
  final double minFill;
  final double aspectTolerance;
  final double maxRotationDeg;
  final double contourSmoothing;
  final int acquireFrames;
  final int loseFrames;
  final int framingGraceMs;

  /// Whether any contour work should happen at all this frame.
  ///
  /// With both flags off the screen must not even build the grid: "inert" has to
  /// mean inert in cost as well as in behaviour, otherwise the P1 and P5 budget
  /// lines move while the feature is supposedly off.
  bool get contourWorkNeeded => contourOverlayEnabled || contourFramingEnabled;

  double sharpnessThresholdFor(DocumentSide side) => side == DocumentSide.recto
      ? rectoSharpnessThreshold
      : versoSharpnessThreshold;
}

/// Whether a `maxRotationDeg` value stays within what the detector's
/// local-fit window can capture on the card's long side, i.e. whether
/// [edgeWindowFraction] (`document_edge_detector.dart`) is wide enough for
/// this angle. Below the bound, the fitted quad's measured rotation reflects
/// the true tilt; above it the fit clips towards the axis, the measurement
/// underestimates, and the `rotation > maxRotationDeg` refusal guard stops
/// firing for a card that is genuinely past range (M2).
///
/// Not a constructor `assert`: `dart:math` functions are not `const`, so this
/// check cannot be folded into [CaptureConfig]'s `const` constructor. Checked
/// instead by a dedicated test, `capture_config_contour_test.dart`, which
/// fails loudly the moment [CaptureConfig.maxRotationDeg]'s default and
/// [edgeWindowFraction] diverge.
bool rotationFitsEdgeWindow(double maxRotationDeg) =>
    math.tan(maxRotationDeg * math.pi / 180) <=
    edgeWindowFraction / idCardAspect;

/// The lens each side uses. Both document sides use the back camera; the selfie
/// uses the front one.
CameraLensDirection lensForSide(DocumentSide side) => CameraLensDirection.back;
