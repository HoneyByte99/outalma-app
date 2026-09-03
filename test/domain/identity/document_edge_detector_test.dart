import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/document_edge_detector.dart';
import 'package:outalma_app/src/domain/identity/document_quad.dart';

/// Builds a [cols]x[rows] grid from a per-cell function.
Uint8List _grid(int cols, int rows, int Function(int x, int y) f) {
  final out = Uint8List(cols * rows);
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      out[y * cols + x] = f(x, y) & 0xff;
    }
  }
  return out;
}

/// A card on a ground, its borders on the given cell indices, both
/// axis-aligned. [ground] and [card] default to a bright card on a dark
/// ground; pass the reverse to build a dark card on a bright ground.
Uint8List _card(
  int cols,
  int rows, {
  required int left,
  required int top,
  required int right,
  required int bottom,
  int ground = 20,
  int card = 230,
  List<({int left, int top, int right, int bottom})> insideBars = const [],
}) {
  return _grid(cols, rows, (x, y) {
    if (x < left || x > right || y < top || y > bottom) return ground;
    for (final bar in insideBars) {
      if (x >= bar.left && x <= bar.right && y >= bar.top && y <= bar.bottom) {
        return ground;
      }
    }
    return card;
  });
}

/// A card built as true membership in a ROTATED rectangle, centred at
/// ([cx], [cy]) with half-extents [halfW] / [halfH].
///
/// Unlike [_card], which is always axis-aligned, this tilts all FOUR borders
/// by [rotationDeg], including the long (horizontal) ones. A shear that only
/// moves `x` by a function of `y`, the fixture this replaces, leaves the top
/// and bottom borders exactly horizontal at any angle: it never exercises the
/// window `_clampWindow` derives for the card's long side (M2), and it halves
/// the rotation `DocumentQuad.inPlaneRotationDeg` reads back, since that
/// average includes two untilted horizontal edges (M5).
Uint8List _cardRotated(
  int cols,
  int rows, {
  required double cx,
  required double cy,
  required double halfW,
  required double halfH,
  required double rotationDeg,
  int ground = 20,
  int card = 230,
}) {
  final angle = rotationDeg * math.pi / 180;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  return _grid(cols, rows, (x, y) {
    final dx = x - cx;
    final dy = y - cy;
    // Coordinates in the card's own (rotated) frame.
    final u = dx * cosA + dy * sinA;
    final v = -dx * sinA + dy * cosA;
    return (u.abs() <= halfW && v.abs() <= halfH) ? card : ground;
  });
}

/// The detector with one set of parameters, so each test states only what it
/// changes. Values are placeholders: the tests prove mechanisms and ordering,
/// never the calibration, which comes from the real-phone pass.
DocumentEdgeObservation _detect(
  Uint8List cells,
  int cols,
  int rows, {
  int planeWidth = 1920,
  int planeHeight = 1080,
  double edgeThreshold = 40,
  double minEdgeSupport = 0.6,
  double minFill = 0.05,
  double aspectTolerance = 0.25,
  double maxRotationDeg = 10,
}) {
  return detectDocumentEdges(
    cells: cells,
    cols: cols,
    rows: rows,
    planeWidth: planeWidth,
    planeHeight: planeHeight,
    edgeThreshold: edgeThreshold,
    minEdgeSupport: minEdgeSupport,
    minFill: minFill,
    aspectTolerance: aspectTolerance,
    maxRotationDeg: maxRotationDeg,
  );
}

void main() {
  group('the minimum-size rule', () {
    // This is what keeps the whole feature additive: the existing capture tests
    // feed 8x8 synthetic planes, they must land on `unknown`, and `unknown`
    // reproduces the pre-contour behaviour bit for bit. Never `none`, which
    // would gate the shutter.
    test('a grid too small to work on reports unknown, never none', () {
      final tiny = _grid(8, 8, (x, y) => (x + y) * 16);
      final observation = _detect(tiny, 8, 8, planeWidth: 8, planeHeight: 8);
      expect(observation.framing, DocumentFraming.unknown);
      expect(observation.quad, isNull);
    });

    test('a plane too small for its grid reports unknown', () {
      final cells = _grid(96, 54, (x, y) => 100);
      final observation = _detect(cells, 96, 54, planeWidth: 8, planeHeight: 8);
      expect(observation.framing, DocumentFraming.unknown);
    });

    test('a truncated cell buffer reports unknown rather than throwing', () {
      final observation = _detect(Uint8List(10), 96, 54);
      expect(observation.framing, DocumentFraming.unknown);
    });
  });

  group('detection', () {
    test('finds the four corners of a bright card on a dark ground', () {
      // 96x54 grid over a 1920x1080 plane makes each cell 20x20 px, i.e.
      // square, so the cell counts ARE the ratio: 60 by 38 is 1.579, the ID-1
      // ratio to within a cell.
      final cells = _card(96, 54, left: 18, top: 8, right: 78, bottom: 46);
      final observation = _detect(cells, 96, 54);

      expect(observation.framing, DocumentFraming.good);
      final quad = observation.quad;
      expect(quad, isNotNull);
      // Corners land on the real borders, to within a cell.
      expect(quad!.topLeft.x, closeTo(18.5 / 96, 3 / 96));
      expect(quad.topLeft.y, closeTo(8.5 / 54, 3 / 54));
      expect(quad.bottomRight.x, closeTo(78.5 / 96, 3 / 96));
      expect(quad.bottomRight.y, closeTo(46.5 / 54, 3 / 54));
      expect(observation.aspect, closeTo(idCardAspect, 0.3));
    });

    test('finds the four corners of a dark card on a bright ground (M1)', () {
      // The inverse polarity of the test above: a card DARKER than its
      // ground, e.g. a dark wallet or a phone case on a light desk. Under
      // the old midpoint-split overflow guard this framed exactly as above
      // reported tooClose with no quad, because the light GROUND read as
      // the "bright" side. Framing must not depend on which side is which.
      final cells = _card(
        96,
        54,
        left: 18,
        top: 8,
        right: 78,
        bottom: 46,
        ground: 210,
        card: 40,
      );
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.good);
      final quad = observation.quad;
      expect(quad, isNotNull);
      expect(quad!.topLeft.x, closeTo(18.5 / 96, 3 / 96));
      expect(quad.bottomRight.x, closeTo(78.5 / 96, 3 / 96));
    });

    test('a flat field reports none', () {
      final flat = _grid(96, 54, (x, y) => 128);
      expect(_detect(flat, 96, 54).framing, DocumentFraming.none);
    });

    test('a card of the wrong shape reports none, not a framing hint', () {
      // A square is not a badly framed card, it is not a card. Saying "move
      // closer" about it would be nonsense for someone who cannot read.
      final square = _card(96, 54, left: 30, top: 12, right: 60, bottom: 42);
      final observation = _detect(square, 96, 54);
      expect(observation.framing, DocumentFraming.none);
      expect(observation.quad, isNull);
    });
  });

  group('the two competitors for a border', () {
    test('strong structures INSIDE the card do not steal the border', () {
      // The real competitor of a low-contrast card edge: on an ID card the
      // portrait, the text columns and the MRZ all produce column sums that
      // beat it. Taking the two STRONGEST peaks would land here.
      final cells = _card(
        96,
        54,
        left: 18,
        top: 8,
        right: 78,
        bottom: 46,
        insideBars: [
          (left: 26, top: 12, right: 30, bottom: 42),
          (left: 40, top: 12, right: 44, bottom: 42),
          (left: 62, top: 12, right: 66, bottom: 42),
        ],
      );
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.good);
      expect(observation.quad!.topLeft.x, closeTo(18.5 / 96, 3 / 96));
      expect(observation.quad!.topRight.x, closeTo(78.5 / 96, 3 / 96));
    });

    test('a hard line OUTSIDE the card does not steal the border either', () {
      // The mirror weakness that "outermost peak" creates on its own: a table
      // edge, a groove or a sheet of paper under the card gives a SHARP peak,
      // unlike random clutter. The inward walk must step past it.
      final base = _card(96, 54, left: 24, top: 8, right: 84, bottom: 46);
      final withOutsideLine = Uint8List.fromList(base);
      for (var y = 0; y < 54; y++) {
        withOutsideLine[y * 96 + 19] = 200;
        withOutsideLine[y * 96 + 20] = 200;
      }
      final observation = _detect(withOutsideLine, 96, 54);

      // Either the card is found, or nothing is. Never the parasite line.
      if (observation.quad != null) {
        expect(observation.quad!.topLeft.x, closeTo(24.5 / 96, 3 / 96));
      } else {
        expect(observation.framing, DocumentFraming.none);
      }
    });

    test('random background clutter does not lose the card', () {
      final rng = math.Random(7);
      final base = _card(96, 54, left: 18, top: 8, right: 78, bottom: 46);
      final noisy = Uint8List.fromList(base);
      for (var y = 0; y < 54; y++) {
        for (var x = 0; x < 96; x++) {
          final insideCard = x >= 18 && x <= 78 && y >= 8 && y <= 46;
          if (!insideCard) {
            noisy[y * 96 + x] = (20 + rng.nextInt(40)) & 0xff;
          }
        }
      }
      expect(_detect(noisy, 96, 54).framing, DocumentFraming.good);
    });
  });

  group('the rotation guard', () {
    test('a card rotated within the supported range is detected, with the '
        'tilt read accurately off its long side (M2)', () {
      // A TRUE rotation (see _cardRotated): tilts the long horizontal
      // borders too, which is the window M2 found clamped to 5.4 degrees
      // against a config that ships maxRotationDeg = 10. A clipped fit
      // would read back well under 8 here, not close to it.
      final cells = _cardRotated(
        96,
        54,
        cx: 48,
        cy: 27,
        halfW: 26,
        halfH: 16,
        rotationDeg: 8,
      );
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.good);
      expect(observation.quad, isNotNull);
      expect(observation.rotationDeg, closeTo(8, 2));
    });

    test('past the supported range it reports unknown and NO quad', () {
      // The decision is a refusal, not a measurement: beyond the range stage 1
      // has no peak left to find, so returning a quad would return a WRONG one.
      final cells = _cardRotated(
        96,
        54,
        cx: 48,
        cy: 27,
        halfW: 26,
        halfH: 16,
        rotationDeg: 15,
      );
      final observation = _detect(cells, 96, 54);
      expect(observation.quad, isNull);
      expect(
        observation.framing,
        anyOf(DocumentFraming.unknown, DocumentFraming.none),
      );
    });
  });

  group('framing categories', () {
    test('a card that is too small reports tooSmall and keeps its quad', () {
      final cells = _card(96, 54, left: 36, top: 20, right: 60, bottom: 35);
      final observation = _detect(cells, 96, 54, minFill: 0.2);
      expect(observation.framing, DocumentFraming.tooSmall);
      expect(observation.quad, isNotNull);
    });

    test('a card overflowing the frame reports tooClose, never none', () {
      // The REAL form of being too close: a border has left the frame, so there
      // is nothing to detect on that side. Every stage downstream would say
      // `none`, i.e. "no card visible" to somebody holding one that fills the
      // screen. No quad here, because the outline genuinely is not knowable.
      final cells = _card(96, 54, left: 0, top: 8, right: 60, bottom: 46);
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.tooClose);
      expect(observation.quad, isNull);
    });

    test('a card overflowing on every side reports tooClose even when it is '
        'darker than its ground (M1)', () {
      // The card fills the whole frame, so the border ring is pure dark
      // card, with one small ground patch tucked away from both the
      // border and the centre-quarter subject sample, just to keep the
      // guard's minimum contrast range satisfied. The OLD midpoint-split
      // code never reads a dark border as "bright", so it MISSES this
      // overflow entirely: a false negative, the mirror image of the
      // false positive covered by the test above.
      final cells = _card(
        96,
        54,
        left: 0,
        top: 0,
        right: 95,
        bottom: 53,
        ground: 210,
        card: 40,
        insideBars: [(left: 2, top: 2, right: 10, bottom: 10)],
      );
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.tooClose);
      expect(observation.quad, isNull);
    });

    test('a wholly visible card pressed against the edge reports tooClose', () {
      // The other half: still detectable, but with no margin left. The
      // tolerance is derived from the grid, because a detected border can never
      // sit closer than cell index 1 and a fixed 0.01 on a 96-cell grid would
      // be finer than one cell, making this branch unreachable.
      final cells = _card(96, 54, left: 2, top: 8, right: 62, bottom: 46);
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.tooClose);
      expect(observation.quad, isNotNull);
    });

    test('a flat field is not mistaken for an overflowing card', () {
      // Without a minimum contrast range, every cell of a flat grey field sits
      // above its own midpoint and the overflow check would fire on nothing.
      final flat = _grid(96, 54, (x, y) => 128);
      expect(_detect(flat, 96, 54).framing, DocumentFraming.none);
    });

    test('the overflow guard ignores bytes past cols * rows (m2)', () {
      // The contract only requires cells.length >= cols * rows (the truncated-
      // buffer test above), which a caller reusing a larger buffer across
      // frames to avoid a per-frame allocation is free to rely on. Low
      // contrast (border 100, card 142, an 84-cell margin all round, well
      // inside the frame) so the guard's own tolerance is narrow: true range
      // 42, tolerance 10.5, border-to-subject gap 42 does not resemble.
      // Appending 0 and 255 past the grid widens a min/max scan over the
      // WHOLE buffer to a 255 range, tolerance 63.75, which DOES resemble,
      // reading the entire (untouched) border as the card and reporting an
      // overflow that is not there.
      final grid = _card(
        96,
        54,
        left: 18,
        top: 8,
        right: 78,
        bottom: 46,
        ground: 100,
        card: 142,
      );
      final reused = Uint8List(grid.length + 2)
        ..setRange(0, grid.length, grid)
        ..[grid.length] = 0
        ..[grid.length + 1] = 255;

      final observation = _detect(reused, 96, 54);
      expect(observation.framing, isNot(DocumentFraming.tooClose));
    });
  });

  group('plausibleRect (m3)', () {
    test('ties on cost break by the LARGER area, not by insertion order', () {
      // Two candidates of EQUAL cost (li=0,ri=1 and li=1,ri=0, both summing
      // to 1): width 120 (area 9600), inserted FIRST by the li/ri loop order,
      // and width 134 (area 10720), inserted second. left=0/right=0 and
      // left=1/right=1 (cost 0 and 2) are deliberately implausible (aspect
      // 1.925 and 1.25, both outside a +/-10% tolerance around idCardAspect),
      // so only the tied pair can be returned, isolating the tie-break.
      //
      // `List.sort` is not stable, so a plain `a.cost.compareTo(b.cost)`
      // leaves which of two equal-cost candidates comes out first to the
      // engine's sort implementation rather than to any rule this file
      // states; on a short list Dart's sort happens to preserve insertion
      // order today, which is what makes the mutation below reliably return
      // the SMALLER (first-inserted) rect instead.
      final rect = plausibleRect(
        lefts: [10, 30],
        rights: [164, 130],
        tops: [10],
        bottoms: [90],
        cols: 200,
        rows: 100,
        planeWidth: 200,
        planeHeight: 100,
        aspectTolerance: 0.1,
      );

      expect(rect, isNotNull);
      expect(
        (left: rect!.left, right: rect.right),
        (left: 30, right: 164),
        reason:
            'the larger (width 134, area 10720) of the two tied '
            'candidates must win, not the smaller (width 120, area 9600)',
      );
    });

    test('replaying the same candidates twice picks the same rectangle', () {
      EdgeRect? run() => plausibleRect(
        lefts: [10, 30],
        rights: [164, 130],
        tops: [10],
        bottoms: [90],
        cols: 200,
        rows: 100,
        planeWidth: 200,
        planeHeight: 100,
        aspectTolerance: 0.1,
      );
      expect(run(), run());
    });
  });

  group('both real plane layouts', () {
    // A platform branch would be a bug factory here, so the ratio is measured
    // long-over-short in plane pixels. Both layouts must score `good` for the
    // same physical card, or every Android capture would be refused.
    test('a card lying across a landscape plane scores good', () {
      final cells = _card(96, 54, left: 18, top: 8, right: 78, bottom: 46);
      final observation = _detect(
        cells,
        96,
        54,
        planeWidth: 1920,
        planeHeight: 1080,
      );
      expect(observation.framing, DocumentFraming.good);
    });

    test('a card standing up a portrait plane scores good', () {
      final cells = _card(54, 96, left: 8, top: 18, right: 46, bottom: 78);
      final observation = _detect(
        cells,
        54,
        96,
        planeWidth: 1080,
        planeHeight: 1920,
      );
      expect(observation.framing, DocumentFraming.good);
    });
  });

  group('parameter validation', () {
    test('throws on a degenerate knob', () {
      final cells = _grid(96, 54, (x, y) => 100);
      expect(
        () => _detect(cells, 96, 54, edgeThreshold: -1),
        throwsArgumentError,
      );
      expect(
        () => _detect(cells, 96, 54, maxRotationDeg: 0),
        throwsArgumentError,
      );
      expect(
        () => _detect(cells, 96, 54, maxRotationDeg: 60),
        throwsArgumentError,
      );
    });
  });
}
