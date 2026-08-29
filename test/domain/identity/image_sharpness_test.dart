import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/image_sharpness.dart';

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
  group('laplacianVariance', () {
    test('is zero for a perfectly flat field (no high frequencies)', () {
      final flat = _plane(16, 16, (_, __) => 128);
      expect(ImageSharpness.laplacianVariance(flat, 16, 16), 0);
    });

    test('a sharp checkerboard scores far higher than a smooth gradient', () {
      final checker = _plane(16, 16, (x, y) => (x + y).isEven ? 0 : 255);
      final gradient = _plane(16, 16, (x, y) => (x * 8) % 256);
      final sharp = ImageSharpness.laplacianVariance(checker, 16, 16);
      final smooth = ImageSharpness.laplacianVariance(gradient, 16, 16);
      expect(sharp, greaterThan(smooth));
      expect(sharp, greaterThan(0));
    });

    test('a blurred edge scores lower than a hard edge', () {
      // Hard vertical edge: black left half, white right half.
      final hard = _plane(16, 16, (x, y) => x < 8 ? 0 : 255);
      // Soft edge: a linear ramp across the middle columns.
      final soft = _plane(16, 16, (x, y) {
        if (x < 6) return 0;
        if (x > 9) return 255;
        return ((x - 6) * 255 / 4).round();
      });
      expect(
        ImageSharpness.laplacianVariance(soft, 16, 16),
        lessThan(ImageSharpness.laplacianVariance(hard, 16, 16)),
      );
    });

    test('honours a padded row stride', () {
      // Two rows of real data (width 3) padded to stride 4; the padding byte
      // must never leak into the computation.
      final padded = Uint8List.fromList([
        10, 20, 30, 99, //
        40, 50, 60, 99, //
        70, 80, 90, 99, //
      ]);
      final tight = Uint8List.fromList([
        10, 20, 30, //
        40, 50, 60, //
        70, 80, 90, //
      ]);
      expect(
        ImageSharpness.laplacianVariance(padded, 3, 3, rowStride: 4),
        ImageSharpness.laplacianVariance(tight, 3, 3),
      );
    });

    test('returns zero rather than throwing on an image too small', () {
      expect(ImageSharpness.laplacianVariance(Uint8List(4), 2, 2), 0);
    });

    test('throws when the buffer is shorter than the dimensions claim', () {
      expect(
        () => ImageSharpness.laplacianVariance(Uint8List(5), 4, 4),
        throwsArgumentError,
      );
    });
  });

  group('laplacianVariance centerFraction', () {
    const size = 40;
    bool isEdge(int x, int y) =>
        x < 8 || y < 8 || x >= size - 8 || y >= size - 8;

    test('defaults to the whole image, so existing callers are unchanged', () {
      final checker = _plane(size, size, (x, y) => (x + y).isEven ? 0 : 255);
      expect(
        ImageSharpness.laplacianVariance(checker, size, size),
        ImageSharpness.laplacianVariance(
          checker,
          size,
          size,
          centerFraction: 1.0,
        ),
      );
    });

    test('a sharp border is ignored when the centre is flat', () {
      // Crisp checkerboard on the edges, dead flat in the middle.
      final sharpEdges = _plane(
        size,
        size,
        (x, y) => isEdge(x, y) ? ((x + y).isEven ? 0 : 255) : 128,
      );
      final cropped = ImageSharpness.laplacianVariance(
        sharpEdges,
        size,
        size,
        centerFraction: 0.4,
      );
      final whole = ImageSharpness.laplacianVariance(sharpEdges, size, size);

      expect(cropped, 0, reason: 'the centre alone carries no detail');
      expect(whole, greaterThan(0), reason: 'the edges do carry detail');
    });

    test('a sharp centre is still seen when the border is flat', () {
      final sharpCentre = _plane(
        size,
        size,
        (x, y) => isEdge(x, y) ? 128 : ((x + y).isEven ? 0 : 255),
      );
      expect(
        ImageSharpness.laplacianVariance(
          sharpCentre,
          size,
          size,
          centerFraction: 0.4,
        ),
        greaterThan(0),
      );
    });

    test('an image too small for the window falls back to the whole plane', () {
      final tiny = _plane(3, 3, (x, y) => (x + y).isEven ? 0 : 255);
      expect(
        ImageSharpness.laplacianVariance(tiny, 3, 3, centerFraction: 0.5),
        ImageSharpness.laplacianVariance(tiny, 3, 3),
      );
    });
  });
}
