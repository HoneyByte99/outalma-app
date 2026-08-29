/// The centred analysis window shared by the two frame measures.
///
/// Both the sharpness variance and the motion signature must look at the SAME
/// region of the luminance plane, otherwise one could call a frame steady while
/// the other judges a different part of it. Keeping the arithmetic in one pure
/// function is what stops the two from drifting apart.
///
/// The window is deliberately NOT aligned pixel for pixel with the framing
/// rectangle drawn on screen: doing that would need the sensor rotation and the
/// preview aspect ratio, which is a bug factory for no benefit. An approximate
/// centred region is enough to drop the periphery, where nobody holds a card.
library;

/// The centred rectangle covering [fraction] of each dimension of a
/// [width] x [height] plane.
///
/// Falls back to the WHOLE image when the resulting window would be degenerate
/// (under 3 pixels on a side), because a window with no interior pixel has no
/// neighbours to differentiate and would silently measure nothing.
({int left, int top, int width, int height}) centerBounds(
  int width,
  int height,
  double fraction,
) {
  final full = (left: 0, top: 0, width: width, height: height);
  if (fraction >= 1) return full;

  final w = (width * fraction).round();
  final h = (height * fraction).round();
  if (w < 3 || h < 3) return full;

  return (left: (width - w) ~/ 2, top: (height - h) ~/ 2, width: w, height: h);
}
