/// Takes a detected outline from luma-plane space into the preview's space.
///
/// There is no letterbox arithmetic here, and that is the point of the design
/// rather than an omission. The page stacks the preview and the overlay as
/// non-positioned siblings of a `Stack(fit: StackFit.expand)`, which hands both
/// of them TIGHT constraints; `RenderAspectRatio` returns `constraints.smallest`
/// on a tight constraint, so the `AspectRatio` that `CameraPreview` wraps itself
/// in is INERT, and the texture is stretched over the whole rectangle. Normalised
/// plane coordinates therefore map LINEARLY onto normalised overlay coordinates,
/// and the painter only has to multiply by its own size.
///
/// An earlier version of this design drew the contour inside its own
/// `Center > AspectRatio` to "recover the letterbox". There is no letterbox to
/// recover: that would have INTRODUCED one, offsetting the contour by about 140
/// logical pixels on a 1080x2400 body. Two widget tests pin the layout premise
/// so a future Flutter or `camera` release cannot move it silently.
///
/// Verified against Flutter 3.41.5 (`rendering/stack.dart`,
/// `rendering/proxy_box.dart`) and camera 0.12.0+2 (`src/camera_preview.dart`).
library;

import 'document_edge_detector.dart' show idCardAspect;
import 'document_quad.dart';

/// Rotates and mirrors [quad] from plane space into preview space.
///
/// [quarterTurns] comes from `previewQuarterTurns`, clockwise, 0 to 3. Both
/// spaces are the unit square, so the rotation is exact and the change of aspect
/// is absorbed by the overlay's own box.
///
/// [mirrored] has NO execution path on the document screen: `lensForSide`
/// returns the back lens for both sides. It exists because the seam may grow a
/// front-lens caller, so its tests do not cover shipped behaviour.
DocumentQuad projectQuadToPreview({
  required DocumentQuad quad,
  required int quarterTurns,
  bool mirrored = false,
}) {
  final turns = ((quarterTurns % 4) + 4) % 4;

  NormPoint map(NormPoint p) {
    var (x, y) = (p.x, p.y);
    for (var i = 0; i < turns; i++) {
      // One clockwise quarter turn of the unit square.
      final nx = 1 - y;
      final ny = x;
      x = nx;
      y = ny;
    }
    if (mirrored) x = 1 - x;
    return (x: x, y: y);
  }

  // The corner NAMES follow the plane, not the card, so after a rotation the
  // ring is re-labelled to keep `topLeft` meaning the preview's top-left. A
  // painter that stroked the ring without this would still draw the right
  // shape, but `topLeft` would lie to every later reader.
  final mapped = [
    map(quad.topLeft),
    map(quad.topRight),
    map(quad.bottomRight),
    map(quad.bottomLeft),
  ];
  final shift = turns % 4;
  NormPoint at(int i) => mapped[(i - shift + 8) % 4];

  return DocumentQuad(
    topLeft: at(0),
    topRight: at(1),
    bottomRight: at(2),
    bottomLeft: at(3),
  );
}

/// Whether a projected quad sits mostly inside the overlay rectangle.
///
/// One net against an absurd overlay, not the only one: it catches a quad
/// thrown mostly off-screen, but a wrong rotation on a CENTERED card (the
/// nominal case, since the template asks to center the card) keeps every
/// corner inside this rectangle regardless, so it slips through untouched.
/// [quadPlausibleInPreview] adds the shape check that catches that case.
///
/// A pure function and not a private helper on the page, for the reason this
/// project has already written down once: a guard living in a widget is covered
/// by nothing, so it has to be a selector. The margin is generous because a
/// correct contour can legitimately touch the frame edge, which is exactly the
/// "too close" case.
bool quadMostlyInside(DocumentQuad quad, {double margin = 0.05}) {
  var inside = 0;
  for (final c in quad.corners) {
    if (c.x >= -margin &&
        c.x <= 1 + margin &&
        c.y >= -margin &&
        c.y <= 1 + margin) {
      inside++;
    }
  }
  return inside >= 3;
}

/// Whether a projected quad both sits inside the frame ([quadMostlyInside])
/// and still has the proportions of a correctly rotated ID card.
///
/// The gap this closes: a card is always drawn LANDSCAPE by the template
/// (`AspectRatio(85.6 / 54)` in `identity_capture_widgets.dart`), on a screen
/// this flow only ever uses in PORTRAIT. So the card's long physical side
/// runs along the preview's SHORT axis (x, width) and its short side along
/// the preview's LONG axis (y, height): the quad's raw normalized aspect
/// (long edge over short edge, uncorrected) reads `idCardAspect *
/// previewAspect`, not `idCardAspect` on its own. [DocumentQuad.planeAspect]
/// divides that scale factor back out when handed a plane whose width:height
/// ratio is `1:previewAspect`, the same one-line trick
/// `document_quad.dart`'s own doc uses to strip the platform's plane
/// orientation out of a rotation-in-degrees measurement.
///
/// [previewAspect] is [PreviewGeometry.aspect] (long side over short side, so
/// it alone cannot say which physical axis is which; the portrait assumption
/// above supplies that). A wrong quarter turn swaps which normalized delta is
/// which, which divides by `previewAspect` where the correct quad multiplies
/// (or the reverse): the resulting aspect lands near `idCardAspect /
/// previewAspect²` or its reciprocal, well outside tolerance for any
/// realistic preview shape, so the rotation is refused rather than drawn.
///
/// What this does NOT catch: a 180-degree error swaps neither axis, so it
/// passes both checks unchanged. That residual stays a phone-pass
/// observation, same as the platform-crop residual `previewMatchesPlane`
/// already documents.
bool quadPlausibleInPreview(
  DocumentQuad quad, {
  required double previewAspect,
}) {
  if (!quadMostlyInside(quad)) return false;
  if (previewAspect <= 0) return false;
  const tolerance = 0.25;
  final aspect = quad.planeAspect(1000, (1000 * previewAspect).round());
  return (aspect - idCardAspect).abs() <= tolerance * idCardAspect;
}

/// Whether the preview and the analysis plane can be assumed to show the same
/// scene, which is the premise the whole contour rests on.
///
/// Nothing in the platform guarantees it. On Android the plugin binds `Preview`,
/// `ImageCapture` and `ImageAnalysis` without a shared `ViewPort` or
/// `UseCaseGroup`, so there is no common crop rectangle between use cases; they
/// share a resolution selector, but its `auto` fallback rule may drop one of
/// them to 4:3 on its own. A 16:9 plane drawn over a 4:3 preview is a contour
/// that is wrong everywhere, and no "is it inside the frame" net catches a
/// systematic error like that.
///
/// So the contour is simply NOT DRAWN when the two disagree. Comparing
/// long-over-short ratios makes the check independent of how each side reports
/// its orientation.
///
/// Necessary, not sufficient: a platform crop at constant ratio passes this and
/// still shifts the field of view. That residual is a phone-pass observation,
/// not something the app can branch on, since the plugin does not expose which
/// preview path is running.
bool previewMatchesPlane({
  required double previewAspect,
  required int planeWidth,
  required int planeHeight,
  double tolerance = 0.02,
}) {
  if (previewAspect <= 0 || planeWidth < 1 || planeHeight < 1) return false;
  final raw = planeWidth / planeHeight;
  final planeAspect = raw >= 1 ? raw : 1 / raw;
  return (previewAspect - planeAspect).abs() <= tolerance * planeAspect;
}
