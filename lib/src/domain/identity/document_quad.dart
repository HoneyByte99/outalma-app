/// The detected document outline, and the vocabulary the screen speaks about it.
///
/// Corners are held in NORMALISED [0,1] coordinates of the luma plane, never in
/// pixels and never in screen space. Three reasons, each one a bug avoided:
///
/// - the plane is 1920x1080 on Android and 1080x1920 on iOS, so pixel
///   coordinates would carry a platform in them;
/// - the preview texture is STRETCHED over the whole overlay rectangle (the
///   `AspectRatio` that `CameraPreview` wraps itself in is inert under
///   `StackFit.expand`), so normalised plane coordinates map linearly onto the
///   overlay and the painter needs no arithmetic of its own;
/// - but a stretched screen space is the wrong place to measure a SHAPE. So
///   every geometric judgement here takes the plane dimensions and works in
///   plane pixels, which is the real geometry of the scene.
library;

import 'dart:math' as math;

/// A corner, in normalised [0,1] coordinates of the luma plane.
typedef NormPoint = ({double x, double y});

/// Four corners in normalised luma-plane coordinates, in ring order.
///
/// The names are about the QUAD's place in the plane, not about the card: the
/// detector builds them from its left, right, top and bottom edge lines, so
/// `topLeft` is the plane's top-left whichever way the card lies.
class DocumentQuad {
  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final NormPoint topLeft;
  final NormPoint topRight;
  final NormPoint bottomRight;
  final NormPoint bottomLeft;

  List<NormPoint> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  /// Fraction of the plane's area this quad covers, by the shoelace formula.
  ///
  /// Normalised coordinates make this a fraction directly. It is also why the
  /// value is comparable across platforms and unaffected by the preview stretch,
  /// which multiplies every area by the same factor.
  double get area {
    final ring = corners;
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum.abs() / 2;
  }

  /// Whether the ring turns the same way at all four corners.
  ///
  /// A non-convex or self-crossing ring is not a card seen through a lens, it is
  /// a detection failure, so the caller refuses it rather than drawing it.
  bool get isConvex {
    final ring = corners;
    var sign = 0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      final c = ring[(i + 2) % ring.length];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross == 0) return false;
      final s = cross > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return true;
  }

  /// Long side over short side, measured in PLANE PIXELS.
  ///
  /// Orientation-agnostic on purpose, and that is what keeps the detector free
  /// of a platform branch. The card lies horizontally in an iOS plane (portrait,
  /// display-oriented) and vertically in an Android plane (landscape, sensor
  /// orientation), so a raw width-over-height compared against the ID-1 ratio of
  /// 1.585 would read 0.63 on every correctly framed Android capture. Returning
  /// the long-over-short ratio closes that without knowing which platform is
  /// running.
  ///
  /// What it gives up, deliberately: it can no longer say "the card is turned 90
  /// degrees from the template". The contour is guidance, not a gate, so that
  /// distinction buys nothing.
  double planeAspect(int planeWidth, int planeHeight) {
    final w =
        (_len(topLeft, topRight, planeWidth, planeHeight) +
            _len(bottomLeft, bottomRight, planeWidth, planeHeight)) /
        2;
    final h =
        (_len(topLeft, bottomLeft, planeWidth, planeHeight) +
            _len(topRight, bottomRight, planeWidth, planeHeight)) /
        2;
    if (w <= 0 || h <= 0) return 0;
    final ratio = w / h;
    return ratio >= 1 ? ratio : 1 / ratio;
  }

  /// Mean tilt of the four edges away from their nearest plane axis, in degrees.
  ///
  /// Measured in plane pixels, and measured on the EDGES rather than guessed
  /// from a bounding box, because the caller uses it as a refusal guard: past
  /// the supported range the detector must return no quad at all rather than a
  /// wrong one. It is therefore computed after the edge lines are fitted, which
  /// is the only stage that knows the real tilt.
  double inPlaneRotationDeg(int planeWidth, int planeHeight) {
    final horizontal = [
      _tiltFromHorizontal(topLeft, topRight, planeWidth, planeHeight),
      _tiltFromHorizontal(bottomLeft, bottomRight, planeWidth, planeHeight),
    ];
    final vertical = [
      _tiltFromVertical(topLeft, bottomLeft, planeWidth, planeHeight),
      _tiltFromVertical(topRight, bottomRight, planeWidth, planeHeight),
    ];
    final all = [...horizontal, ...vertical];
    return all.reduce((a, b) => a + b) / all.length;
  }

  /// Whether any corner sits within [tolerance] of a plane edge.
  ///
  /// This is how "too close" is decided, and it is geometric on purpose. An
  /// area-fraction threshold cannot do it: the card's long side lands on the
  /// plane's SHORT side in both real layouts, so the largest fill an ID-1 card
  /// can physically reach is about 0.355, and any "maxFill" above that is a
  /// branch that never runs.
  bool touchesPlaneEdge({double tolerance = 0.01}) {
    for (final c in corners) {
      if (c.x <= tolerance ||
          c.y <= tolerance ||
          c.x >= 1 - tolerance ||
          c.y >= 1 - tolerance) {
        return true;
      }
    }
    return false;
  }

  static double _len(NormPoint a, NormPoint b, int planeW, int planeH) {
    final dx = (b.x - a.x) * planeW;
    final dy = (b.y - a.y) * planeH;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _tiltFromHorizontal(
    NormPoint a,
    NormPoint b,
    int planeW,
    int planeH,
  ) {
    final dx = ((b.x - a.x) * planeW).abs();
    final dy = (b.y - a.y) * planeH;
    if (dx == 0) return 90;
    return _deg(math.atan(dy.abs() / dx));
  }

  static double _tiltFromVertical(
    NormPoint a,
    NormPoint b,
    int planeW,
    int planeH,
  ) {
    final dx = (b.x - a.x) * planeW;
    final dy = ((b.y - a.y) * planeH).abs();
    if (dy == 0) return 90;
    return _deg(math.atan(dx.abs() / dy));
  }

  static double _deg(double radians) => radians * 180 / math.pi;
}

/// What the screen knows about the framing.
///
/// [unknown] REPRODUCES the behaviour from before contour detection existed, bit
/// for bit, and it is the default everywhere: it is what a frame too small for
/// the grid reports, what the shutter is handed while the feature flag is off,
/// and what the fallback degrades to once the grace window expires.
///
/// A wrong aspect ratio reports [none], not a framing category: a shape that is
/// not a card's shape is not a badly framed card, it is the absence of a
/// credible card. Telling someone to move closer when they are too close, or
/// that no card is visible when one fills the frame, is exactly the kind of
/// nonsense a provider who cannot read has no way to recover from.
enum DocumentFraming { unknown, none, tooSmall, tooClose, good }
