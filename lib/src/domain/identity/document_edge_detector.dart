/// Finds the document outline in a downsampled luminance grid.
///
/// Two stages, because one alone does not work.
///
/// **Stage 1, global: projection profiles.** A Sobel over the grid, then `|gx|`
/// summed down the columns and `|gy|` across the rows. Summing every row averages
/// out background clutter, which a row-by-row scan cannot do.
///
/// It picks the OUTERMOST peaks above the threshold, not the two strongest, and
/// then walks inwards while the resulting rectangle is not a plausible card
/// shape. Both halves of that sentence are load-bearing:
///
/// - "not the two strongest", because on a real ID card the portrait, the text
///   columns and the MRZ produce column sums that beat a low-contrast card edge.
///   The real competitor is the INSIDE of the card, not the background;
/// - "walks inwards while implausible", because taking the outermost peak alone
///   swaps that weakness for its mirror image: any hard line OUTSIDE the card (a
///   table edge, a groove, a drop shadow, a sheet of paper underneath) would
///   steal the border, and unlike random clutter it produces a SHARP peak.
///
/// **Stage 2, local: four fitted lines.** Around each border found by stage 1, the
/// per-row (or per-column) gradient maximum is collected and a line is fitted by
/// least squares, which recovers a slightly tilted quad. `x = a*y + b` for the
/// near-vertical borders and `y = c*x + d` for the near-horizontal ones, never
/// the other way round: an infinite slope would blow the fit up.
///
/// The search half-window is derived from [maxRotationDeg] PER BORDER, from the
/// border's own span along its long direction. Too narrow and the fit is clipped
/// towards the axis, so the rotation is underestimated, so the out-of-range guard
/// never fires and a wrong quad is returned. Too wide and the per-row maximum
/// locks onto a structure inside the card instead. The same damage from either
/// end, which is why the window is computed rather than tuned.
///
/// **Rotation is a refusal, not a measurement.** Past [maxRotationDeg] stage 1
/// has no peak left to find anyway, so the honest answer is "I cannot see a
/// card": the observation comes back `unknown` with NO quad. Never a wrong one.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'document_quad.dart';

/// The ID-1 ratio of a national identity card (85.6 x 54 mm).
const double idCardAspect = 85.6 / 54;

/// One framing observation over one analysed frame.
class DocumentEdgeObservation {
  const DocumentEdgeObservation({
    required this.framing,
    this.quad,
    this.fill = 0,
    this.aspect = 0,
    this.edgeSupport = 0,
    this.rotationDeg = 0,
  });

  /// What the screen should say about the framing.
  final DocumentFraming framing;

  /// The outline, or null when there is nothing credible to draw. Always null
  /// outside the supported rotation range, and always null when [framing] is
  /// [DocumentFraming.unknown] or [DocumentFraming.none].
  final DocumentQuad? quad;

  /// Reported for calibration, never used to decide anything by the caller.
  final double fill;
  final double aspect;
  final double edgeSupport;
  final double rotationDeg;

  /// Nothing could be judged. Reproduces the pre-contour behaviour exactly.
  static const DocumentEdgeObservation unknown = DocumentEdgeObservation(
    framing: DocumentFraming.unknown,
  );

  /// Frames arrive and are readable, but no credible card is in them.
  static const DocumentEdgeObservation none = DocumentEdgeObservation(
    framing: DocumentFraming.none,
  );
}

/// Runs the two stages over [cells], a [cols] x [rows] grid from `LumaGrid`.
///
/// [planeWidth] and [planeHeight] are the real luma plane dimensions, needed
/// because every shape judgement happens in plane pixels, not in grid cells and
/// not on screen.
///
/// Returns [DocumentEdgeObservation.unknown] rather than `none` when the frame
/// is too small for the grid. That distinction is what keeps this feature purely
/// additive: the existing capture tests feed 8x8 synthetic planes, they land on
/// `unknown`, and `unknown` reproduces the old behaviour bit for bit.
DocumentEdgeObservation detectDocumentEdges({
  required Uint8List cells,
  required int cols,
  required int rows,
  required int planeWidth,
  required int planeHeight,
  required double edgeThreshold,
  required double minEdgeSupport,
  required double minFill,
  required double aspectTolerance,
  required double maxRotationDeg,
}) {
  if (edgeThreshold < 0) {
    throw ArgumentError.value(
      edgeThreshold,
      'edgeThreshold',
      'cannot be negative',
    );
  }
  if (maxRotationDeg <= 0 || maxRotationDeg >= 45) {
    throw ArgumentError.value(
      maxRotationDeg,
      'maxRotationDeg',
      'must be inside (0, 45)',
    );
  }

  // The minimum-size rule. Stated against the DERIVED grid, and against the
  // room the two stages actually need: a Sobel drops the border ring, and the
  // profiles need somewhere to put a peak.
  const minCells = 12;
  if (cols < minCells || rows < minCells) {
    return DocumentEdgeObservation.unknown;
  }
  if (cells.length < cols * rows) return DocumentEdgeObservation.unknown;
  if (planeWidth < cols * 2 || planeHeight < rows * 2) {
    return DocumentEdgeObservation.unknown;
  }

  // "Too close" is decided BEFORE looking for borders, because the real form of
  // being too close is that a border has left the frame entirely: there is then
  // nothing to detect on that side, and every downstream stage would report
  // `none`, i.e. "no card visible" to somebody holding one that fills the
  // screen. That is the nonsense this branch exists to prevent.
  if (_overflowsFrame(cells, cols, rows)) {
    return const DocumentEdgeObservation(framing: DocumentFraming.tooClose);
  }

  final gx = Float32List(cols * rows);
  final gy = Float32List(cols * rows);
  _sobel(cells, cols, rows, gx, gy);

  // Mean |gradient| per column and per row, so the threshold means the same
  // thing whatever the grid size.
  final colProfile = Float32List(cols);
  final rowProfile = Float32List(rows);
  for (var y = 1; y < rows - 1; y++) {
    for (var x = 1; x < cols - 1; x++) {
      colProfile[x] += gx[y * cols + x].abs();
      rowProfile[y] += gy[y * cols + x].abs();
    }
  }
  final interiorRows = rows - 2;
  final interiorCols = cols - 2;
  for (var x = 0; x < cols; x++) {
    colProfile[x] /= interiorRows;
  }
  for (var y = 0; y < rows; y++) {
    rowProfile[y] /= interiorCols;
  }

  final vertical = _peaks(colProfile, edgeThreshold);
  final horizontal = _peaks(rowProfile, edgeThreshold);
  if (vertical.length < 2 || horizontal.length < 2) {
    return DocumentEdgeObservation.none;
  }

  // Candidates ordered outermost first, capped: three from each side is enough
  // to step past a table edge or a shadow, and keeps the search at 81 cheap
  // combinations in the worst case.
  const maxCandidates = 3;
  final lefts = vertical.take(maxCandidates).toList();
  final rights = vertical.reversed.take(maxCandidates).toList();
  final tops = horizontal.take(maxCandidates).toList();
  final bottoms = horizontal.reversed.take(maxCandidates).toList();

  final rect = _plausibleRect(
    lefts: lefts,
    rights: rights,
    tops: tops,
    bottoms: bottoms,
    cols: cols,
    rows: rows,
    planeWidth: planeWidth,
    planeHeight: planeHeight,
    aspectTolerance: aspectTolerance,
  );
  if (rect == null) return DocumentEdgeObservation.none;

  final refined = _refine(
    gx: gx,
    gy: gy,
    cols: cols,
    rows: rows,
    rect: rect,
    edgeThreshold: edgeThreshold,
    maxRotationDeg: maxRotationDeg,
  );
  if (refined == null) return DocumentEdgeObservation.none;

  final quad = refined.quad;
  final rotation = quad.inPlaneRotationDeg(planeWidth, planeHeight);

  // 1. Rotation: a refusal, and the quad is dropped with it.
  if (rotation > maxRotationDeg) {
    return DocumentEdgeObservation(
      framing: DocumentFraming.unknown,
      rotationDeg: rotation,
      edgeSupport: refined.support,
    );
  }

  // 2. Edge support.
  if (refined.support < minEdgeSupport) {
    return DocumentEdgeObservation(
      framing: DocumentFraming.none,
      edgeSupport: refined.support,
      rotationDeg: rotation,
    );
  }

  // 3. Convexity.
  if (!quad.isConvex) {
    return DocumentEdgeObservation(
      framing: DocumentFraming.none,
      edgeSupport: refined.support,
      rotationDeg: rotation,
    );
  }

  final aspect = quad.planeAspect(planeWidth, planeHeight);
  final fill = quad.area;

  // 4. Shape. A wrong ratio is NOT a framing category: it is the absence of a
  // credible card, so it reports `none` and never "move closer".
  if ((aspect - idCardAspect).abs() > aspectTolerance * idCardAspect) {
    return DocumentEdgeObservation(
      framing: DocumentFraming.none,
      aspect: aspect,
      fill: fill,
      edgeSupport: refined.support,
      rotationDeg: rotation,
    );
  }

  // 5. Too small.
  if (fill < minFill) {
    return DocumentEdgeObservation(
      framing: DocumentFraming.tooSmall,
      quad: quad,
      aspect: aspect,
      fill: fill,
      edgeSupport: refined.support,
      rotationDeg: rotation,
    );
  }

  // 6. Too close while still wholly visible, decided GEOMETRICALLY. An area
  // ceiling cannot do this job: the card's long side lands on the plane's short
  // side in both real layouts, so an ID-1 card cannot physically cover more
  // than about 0.355 of the plane, and any threshold above that never runs.
  //
  // The tolerance is derived from the GRID rather than being a constant, for
  // the same reason: a detected border can never sit closer to the frame than
  // cell index 1, so a fixed 0.01 on a 96-cell grid would be finer than one
  // cell and this branch could not fire either.
  final touchTolerance = 1.5 / math.min(cols, rows);
  if (quad.touchesPlaneEdge(tolerance: touchTolerance)) {
    return DocumentEdgeObservation(
      framing: DocumentFraming.tooClose,
      quad: quad,
      aspect: aspect,
      fill: fill,
      edgeSupport: refined.support,
      rotationDeg: rotation,
    );
  }

  return DocumentEdgeObservation(
    framing: DocumentFraming.good,
    quad: quad,
    aspect: aspect,
    fill: fill,
    edgeSupport: refined.support,
    rotationDeg: rotation,
  );
}

/// Whether a whole side of the frame is filled by the subject.
///
/// Checked per SIDE rather than over the border ring as a whole: a card that is
/// too close usually overflows on one or two sides, never on all four, so a ring
/// average would stay low and the branch would never fire. That is the same
/// mistake as an area ceiling above the physical maximum, in another guise.
///
/// Decided by resemblance to the SUBJECT, read from the grid's centre where the
/// template asks the card to sit, rather than by a global midpoint split. A
/// midpoint split assumes the subject is the brighter half of the frame, which
/// fails as often as it holds: a dark card on a light table (a bright surface,
/// a sheet of paper) is exactly as common as the reverse, and under that split
/// its light BACKGROUND would be read as "bright", flipping every side count.
///
/// A minimum contrast range is required first, otherwise a flat grey field, in
/// which every cell reads as its own subject, would report as overflowing.
bool _overflowsFrame(Uint8List cells, int cols, int rows) {
  const minRange = 40;
  const sideFraction = 0.5;

  var min = 255;
  var max = 0;
  for (final v in cells) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  if (max - min < minRange) return false;

  final subject = _meanOfCentre(cells, cols, rows);
  final tolerance = (max - min) * 0.25;
  bool resemblesSubject(int v) => (v - subject).abs() < tolerance;

  var topCovered = 0;
  var bottomCovered = 0;
  for (var x = 0; x < cols; x++) {
    if (resemblesSubject(cells[x])) topCovered++;
    if (resemblesSubject(cells[(rows - 1) * cols + x])) bottomCovered++;
  }
  var leftCovered = 0;
  var rightCovered = 0;
  for (var y = 0; y < rows; y++) {
    if (resemblesSubject(cells[y * cols])) leftCovered++;
    if (resemblesSubject(cells[y * cols + cols - 1])) rightCovered++;
  }

  return topCovered / cols > sideFraction ||
      bottomCovered / cols > sideFraction ||
      leftCovered / rows > sideFraction ||
      rightCovered / rows > sideFraction;
}

/// Mean value of the grid's central quarter, where the template asks the
/// subject to sit, whichever way its luminance compares to the background.
double _meanOfCentre(Uint8List cells, int cols, int rows) {
  final x0 = cols ~/ 4;
  final x1 = cols - x0;
  final y0 = rows ~/ 4;
  final y1 = rows - y0;
  var sum = 0;
  var count = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      sum += cells[y * cols + x];
      count++;
    }
  }
  return sum / count;
}

void _sobel(
  Uint8List cells,
  int cols,
  int rows,
  Float32List gx,
  Float32List gy,
) {
  for (var y = 1; y < rows - 1; y++) {
    for (var x = 1; x < cols - 1; x++) {
      final i = y * cols + x;
      final tl = cells[i - cols - 1];
      final t = cells[i - cols];
      final tr = cells[i - cols + 1];
      final l = cells[i - 1];
      final r = cells[i + 1];
      final bl = cells[i + cols - 1];
      final b = cells[i + cols];
      final br = cells[i + cols + 1];
      gx[i] = (tr + 2 * r + br - tl - 2 * l - bl).toDouble();
      gy[i] = (bl + 2 * b + br - tl - 2 * t - tr).toDouble();
    }
  }
}

/// Local maxima of [profile] above [threshold], ascending, non-maximum
/// suppressed so one thick border does not report as several.
List<int> _peaks(Float32List profile, double threshold) {
  const suppression = 2;
  final found = <int>[];
  for (var i = 1; i < profile.length - 1; i++) {
    final v = profile[i];
    if (v < threshold) continue;
    var isLocalMax = true;
    for (var d = 1; d <= suppression; d++) {
      final lo = i - d;
      final hi = i + d;
      if (lo >= 0 && profile[lo] > v) isLocalMax = false;
      if (hi < profile.length && profile[hi] > v) isLocalMax = false;
    }
    if (!isLocalMax) continue;
    if (found.isNotEmpty && i - found.last <= suppression) {
      if (v > profile[found.last]) found[found.length - 1] = i;
      continue;
    }
    found.add(i);
  }
  return found;
}

typedef _Rect = ({int left, int top, int right, int bottom});

/// The outermost candidate rectangle whose shape could be a card.
///
/// Combinations are visited by ascending index sum, i.e. outermost first, and
/// the first plausible one wins. That ordering IS the "walk inwards while
/// implausible" rule: it keeps a genuine card border ahead of an inner text
/// column, while still stepping past a table edge outside the card.
_Rect? _plausibleRect({
  required List<int> lefts,
  required List<int> rights,
  required List<int> tops,
  required List<int> bottoms,
  required int cols,
  required int rows,
  required int planeWidth,
  required int planeHeight,
  required double aspectTolerance,
}) {
  const minSpan = 4;
  final combos = <({int cost, _Rect rect})>[];
  for (var li = 0; li < lefts.length; li++) {
    for (var ri = 0; ri < rights.length; ri++) {
      for (var ti = 0; ti < tops.length; ti++) {
        for (var bi = 0; bi < bottoms.length; bi++) {
          final left = lefts[li];
          final right = rights[ri];
          final top = tops[ti];
          final bottom = bottoms[bi];
          if (right - left < minSpan || bottom - top < minSpan) continue;
          combos.add((
            cost: li + ri + ti + bi,
            rect: (left: left, top: top, right: right, bottom: bottom),
          ));
        }
      }
    }
  }
  combos.sort((a, b) => a.cost.compareTo(b.cost));

  for (final combo in combos) {
    final quad = _rectToQuad(combo.rect, cols, rows);
    final aspect = quad.planeAspect(planeWidth, planeHeight);
    if ((aspect - idCardAspect).abs() <= aspectTolerance * idCardAspect) {
      return combo.rect;
    }
  }
  return null;
}

DocumentQuad _rectToQuad(_Rect rect, int cols, int rows) {
  final l = _norm(rect.left, cols);
  final r = _norm(rect.right, cols);
  final t = _norm(rect.top, rows);
  final b = _norm(rect.bottom, rows);
  return DocumentQuad(
    topLeft: (x: l, y: t),
    topRight: (x: r, y: t),
    bottomRight: (x: r, y: b),
    bottomLeft: (x: l, y: b),
  );
}

/// Cell index to normalised coordinate, at the CELL CENTRE.
double _norm(int index, int count) => (index + 0.5) / count;

typedef _Refined = ({DocumentQuad quad, double support});

/// Fits a line to each of the four borders and intersects them.
_Refined? _refine({
  required Float32List gx,
  required Float32List gy,
  required int cols,
  required int rows,
  required _Rect rect,
  required double edgeThreshold,
  required double maxRotationDeg,
}) {
  final tan = math.tan(maxRotationDeg * math.pi / 180);
  final spanY = rect.bottom - rect.top;
  final spanX = rect.right - rect.left;

  // Per border, from its OWN span along its long direction, clamped both ways.
  final verticalWindow = _clampWindow(spanY * tan, spanX);
  final horizontalWindow = _clampWindow(spanX * tan, spanY);

  var collected = 0;
  var expected = 0;

  final left = _fitVertical(
    gx,
    cols,
    rows,
    rect.left,
    rect.top,
    rect.bottom,
    verticalWindow,
    edgeThreshold,
  );
  final right = _fitVertical(
    gx,
    cols,
    rows,
    rect.right,
    rect.top,
    rect.bottom,
    verticalWindow,
    edgeThreshold,
  );
  final top = _fitHorizontal(
    gy,
    cols,
    rows,
    rect.top,
    rect.left,
    rect.right,
    horizontalWindow,
    edgeThreshold,
  );
  final bottom = _fitHorizontal(
    gy,
    cols,
    rows,
    rect.bottom,
    rect.left,
    rect.right,
    horizontalWindow,
    edgeThreshold,
  );
  if (left == null || right == null || top == null || bottom == null) {
    return null;
  }
  for (final fit in [left, right, top, bottom]) {
    collected += fit.count;
    expected += fit.expected;
  }

  final topLeft = _intersect(left, top);
  final topRight = _intersect(right, top);
  final bottomRight = _intersect(right, bottom);
  final bottomLeft = _intersect(left, bottom);
  if (topLeft == null ||
      topRight == null ||
      bottomRight == null ||
      bottomLeft == null) {
    return null;
  }

  final quad = DocumentQuad(
    topLeft: (x: _norm2(topLeft.x, cols), y: _norm2(topLeft.y, rows)),
    topRight: (x: _norm2(topRight.x, cols), y: _norm2(topRight.y, rows)),
    bottomRight: (
      x: _norm2(bottomRight.x, cols),
      y: _norm2(bottomRight.y, rows),
    ),
    bottomLeft: (x: _norm2(bottomLeft.x, cols), y: _norm2(bottomLeft.y, rows)),
  );
  return (quad: quad, support: expected == 0 ? 0 : collected / expected);
}

double _norm2(double index, int count) => (index + 0.5) / count;

/// Fraction of a border's transverse span the local line-fit search window
/// may cover, per [_clampWindow].
///
/// Public so [maxRotationDeg] can be asserted against it at the config layer:
/// for the two LONG sides of an ID-1 card, `L / T = idCardAspect`, so the
/// window this function allows must reach at least
/// `idCardAspect * tan(maxRotationDeg)` or the long-side fit is clipped
/// towards the axis, [DocumentQuad.inPlaneRotationDeg] underestimates the true
/// tilt, and the `rotation > maxRotationDeg` refusal guard never fires for a
/// card that is actually past the supported range. At `maxRotationDeg = 10`
/// that floor is `1.585 * tan(10deg) ~= 0.28`; `0.30` keeps a margin without
/// widening enough to lock onto structure inside the card (verified against
/// the `insideBars` fixture in `document_edge_detector_test.dart`).
const double edgeWindowFraction = 0.30;

double _clampWindow(double ideal, int transverse) {
  final upper = math.max(2.0, transverse * edgeWindowFraction);
  return ideal.clamp(2.0, upper);
}

/// A fitted border line, plus how much real gradient backed it.
///
/// [slope] and [offset] read as `main = slope * cross + offset`: for a vertical
/// border that is `x = a*y + b`, for a horizontal one `y = c*x + d`.
typedef _Fit = ({
  double slope,
  double offset,
  bool isVertical,
  int count,
  int expected,
});

_Fit? _fitVertical(
  Float32List gx,
  int cols,
  int rows,
  int at,
  int from,
  int to,
  double window,
  double edgeThreshold,
) {
  final xs = <double>[];
  final ys = <double>[];
  final lo = math.max(1, from);
  final hi = math.min(rows - 2, to);
  for (var y = lo; y <= hi; y++) {
    var bestX = -1;
    var best = 0.0;
    final searchLo = math.max(1, (at - window).floor());
    final searchHi = math.min(cols - 2, (at + window).ceil());
    for (var x = searchLo; x <= searchHi; x++) {
      final v = gx[y * cols + x].abs();
      if (v > best) {
        best = v;
        bestX = x;
      }
    }
    if (bestX >= 0 && best >= edgeThreshold) {
      xs.add(bestX.toDouble());
      ys.add(y.toDouble());
    }
  }
  final expected = hi - lo + 1;
  if (xs.length < 3) return null;
  final rough = _leastSquares(ys, xs);
  if (rough == null) return null;
  final line = _dropFitOutliers(ys, xs, rough) ?? rough;
  return (
    slope: line.slope,
    offset: line.offset,
    isVertical: true,
    count: xs.length,
    expected: expected,
  );
}

_Fit? _fitHorizontal(
  Float32List gy,
  int cols,
  int rows,
  int at,
  int from,
  int to,
  double window,
  double edgeThreshold,
) {
  final xs = <double>[];
  final ys = <double>[];
  final lo = math.max(1, from);
  final hi = math.min(cols - 2, to);
  for (var x = lo; x <= hi; x++) {
    var bestY = -1;
    var best = 0.0;
    final searchLo = math.max(1, (at - window).floor());
    final searchHi = math.min(rows - 2, (at + window).ceil());
    for (var y = searchLo; y <= searchHi; y++) {
      final v = gy[y * cols + x].abs();
      if (v > best) {
        best = v;
        bestY = y;
      }
    }
    if (bestY >= 0 && best >= edgeThreshold) {
      xs.add(x.toDouble());
      ys.add(bestY.toDouble());
    }
  }
  final expected = hi - lo + 1;
  if (xs.length < 3) return null;
  final rough = _leastSquares(xs, ys);
  if (rough == null) return null;
  final line = _dropFitOutliers(xs, ys, rough) ?? rough;
  return (
    slope: line.slope,
    offset: line.offset,
    isVertical: false,
    count: ys.length,
    expected: expected,
  );
}

/// Refits after dropping points whose residual from [line] exceeds a few
/// cells, then returns null if that changed nothing or left too few points.
///
/// Near a rotated card's corner, the fixed-window per-row (or per-column)
/// search of [_fitVertical] / [_fitHorizontal] can lock onto the ADJACENT
/// border instead of this one for the rows (or columns) past where the true
/// corner already crossed over: the stage-1 rect is an axis-aligned box
/// around a tilted card, so it always overshoots one edge's real extent
/// near each corner. A handful of such points sit at the extremes of the
/// search range, where a least-squares fit has the most leverage, and can
/// pull a clean line's slope towards zero, i.e. underestimate the tilt: the
/// exact failure `rotation > maxRotationDeg` exists to catch (M2). On a
/// clean synthetic edge every residual sits near zero, so this is a no-op
/// there.
({double slope, double offset})? _dropFitOutliers(
  List<double> a,
  List<double> b,
  ({double slope, double offset}) line,
) {
  const maxResidual = 2.5;
  final keptA = <double>[];
  final keptB = <double>[];
  for (var i = 0; i < a.length; i++) {
    final predicted = line.slope * a[i] + line.offset;
    if ((b[i] - predicted).abs() <= maxResidual) {
      keptA.add(a[i]);
      keptB.add(b[i]);
    }
  }
  if (keptA.length == a.length || keptA.length < 3) return null;
  return _leastSquares(keptA, keptB);
}

({double slope, double offset})? _leastSquares(
  List<double> xs,
  List<double> ys,
) {
  final n = xs.length;
  var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
  for (var i = 0; i < n; i++) {
    sx += xs[i];
    sy += ys[i];
    sxx += xs[i] * xs[i];
    sxy += xs[i] * ys[i];
  }
  final denom = n * sxx - sx * sx;
  if (denom.abs() < 1e-9) return null;
  final slope = (n * sxy - sx * sy) / denom;
  final offset = (sy - slope * sx) / n;
  return (slope: slope, offset: offset);
}

({double x, double y})? _intersect(_Fit a, _Fit b) {
  final v = a.isVertical ? a : b;
  final h = a.isVertical ? b : a;
  if (v.isVertical == h.isVertical) return null;
  // x = av*y + bv and y = ch*x + dh
  final denom = 1 - h.slope * v.slope;
  if (denom.abs() < 1e-9) return null;
  final y = (h.slope * v.offset + h.offset) / denom;
  final x = v.slope * y + v.offset;
  return (x: x, y: y);
}
