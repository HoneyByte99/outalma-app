import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/luma_grid.dart';

/// Builds a [width]x[height] luminance plane from a per-pixel function.
Uint8List _plane(int width, int height, int Function(int x, int y) f) {
  final out = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out[y * width + x] = f(x, y) & 0xff;
    }
  }
  return out;
}

void main() {
  group('gridFor', () {
    test('puts the long side on the wider dimension', () {
      expect(LumaGrid.gridFor(1920, 1080, 96), (96, 54));
      expect(LumaGrid.gridFor(1080, 1920, 96), (54, 96));
    });

    test('keeps cells near-square in both plane orientations', () {
      // A cell is width/cols by height/rows. The two must stay close, which is
      // the whole point of deriving the grid instead of fixing it.
      for (final (w, h) in const [(1920, 1080), (1080, 1920), (640, 480)]) {
        final (cols, rows) = LumaGrid.gridFor(w, h, 96);
        final ratio = (w / cols) / (h / rows);
        expect(ratio, closeTo(1, 0.05), reason: '${w}x$h gave ${cols}x$rows');
      }
    });

    test('never returns a zero side, however extreme the frame', () {
      final (cols, rows) = LumaGrid.gridFor(1000, 1, 96);
      expect(cols, 96);
      expect(rows, 1);
    });

    test('is zero for a degenerate frame', () {
      expect(LumaGrid.gridFor(0, 10, 96), (0, 0));
    });
  });

  group('sample', () {
    test('returns a grid of the derived dimensions', () {
      final plane = _plane(320, 180, (x, y) => x + y);
      final sample = LumaGrid.sample(plane, 320, 180, longSide: 96);
      expect(sample.cols, 96);
      expect(sample.rows, 54);
      expect(sample.cells.length, 96 * 54);
    });

    test('honours a padded row stride', () {
      // Real data is 3 wide, padded to stride 4. The padding byte (99) must
      // never reach a cell.
      final padded = Uint8List.fromList([
        10, 10, 10, 99, //
        10, 10, 10, 99, //
        10, 10, 10, 99, //
      ]);
      final sample = LumaGrid.sample(
        padded,
        3,
        3,
        rowStride: 4,
        longSide: 3,
        samplesPerCell: 1,
      );
      expect(sample.cells.every((v) => v == 10), isTrue);
    });

    test('averages, so a checkerboard flattens instead of aliasing', () {
      // Point sampling a checkerboard at even decimation reads one phase and
      // reports a hard 0/255 pattern. Averaging reports mid-grey, which is what
      // stops a Sobel from seeing edges that are not there.
      final checker = _plane(96, 96, (x, y) => (x + y).isEven ? 0 : 255);
      final averaged = LumaGrid.sample(
        checker,
        96,
        96,
        longSide: 12,
        samplesPerCell: 4,
      );
      for (final v in averaged.cells) {
        expect(v, closeTo(128, 40));
      }

      final pointSampled = LumaGrid.sample(
        checker,
        96,
        96,
        longSide: 12,
        samplesPerCell: 1,
      );
      // The single-sample grid keeps the extremes; the averaged one does not.
      expect(pointSampled.cells.any((v) => v == 0 || v == 255), isTrue);
      expect(averaged.cells.any((v) => v == 0 || v == 255), isFalse);
    });

    test('reads the WHOLE plane, edges included', () {
      // The opposite choice from the two existing measures, which crop to
      // centerBounds. A card touching the border must still be visible here.
      final borderOnly = _plane(
        90,
        90,
        (x, y) => (x < 3 || y < 3 || x > 86 || y > 86) ? 255 : 0,
      );
      final sample = LumaGrid.sample(
        borderOnly,
        90,
        90,
        longSide: 30,
        samplesPerCell: 3,
      );
      final firstCell = sample.cells.first;
      final lastCell = sample.cells.last;
      expect(firstCell, greaterThan(0));
      expect(lastCell, greaterThan(0));
    });

    test('returns an empty sample for a degenerate frame', () {
      final sample = LumaGrid.sample(Uint8List(0), 0, 0);
      expect(sample.cells, isEmpty);
      expect(sample.cols, 0);
      expect(sample.rows, 0);
    });

    test('throws when the buffer is shorter than the dimensions claim', () {
      expect(() => LumaGrid.sample(Uint8List(10), 8, 8), throwsArgumentError);
    });

    test('throws on a degenerate knob', () {
      final plane = _plane(16, 16, (x, y) => 100);
      expect(
        () => LumaGrid.sample(plane, 16, 16, longSide: 0),
        throwsArgumentError,
      );
      expect(
        () => LumaGrid.sample(plane, 16, 16, samplesPerCell: 0),
        throwsArgumentError,
      );
    });
  });
}
