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

/// A bright card on a dark ground, its borders on the given cell indices.
/// [rotationDeg] shears the card in-plane so the tilt guard can be exercised.
Uint8List _card(
  int cols,
  int rows, {
  required int left,
  required int top,
  required int right,
  required int bottom,
  double rotationDeg = 0,
  int ground = 20,
  int card = 230,
  List<({int left, int top, int right, int bottom})> insideBars = const [],
}) {
  final tan = math.tan(rotationDeg * math.pi / 180);
  final midY = (top + bottom) / 2;
  return _grid(cols, rows, (x, y) {
    // Shearing x by the distance from the card's middle row rotates the two
    // vertical borders without changing the card's height.
    final shift = ((y - midY) * tan).round();
    final l = left + shift;
    final r = right + shift;
    if (x < l || x > r || y < top || y > bottom) return ground;
    for (final bar in insideBars) {
      if (x >= bar.left + shift &&
          x <= bar.right + shift &&
          y >= bar.top &&
          y <= bar.bottom) {
        return ground;
      }
    }
    return card;
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
    test('a slightly tilted card is still detected', () {
      final cells = _card(
        96,
        54,
        left: 18,
        top: 8,
        right: 78,
        bottom: 46,
        rotationDeg: 6,
      );
      final observation = _detect(cells, 96, 54);
      expect(observation.framing, DocumentFraming.good);
      expect(observation.rotationDeg, greaterThan(0));
    });

    test('past the supported range it reports unknown and NO quad', () {
      // The decision is a refusal, not a measurement: beyond the range stage 1
      // has no peak left to find, so returning a quad would return a WRONG one.
      final cells = _card(
        96,
        54,
        left: 26,
        top: 8,
        right: 78,
        bottom: 46,
        rotationDeg: 25,
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
