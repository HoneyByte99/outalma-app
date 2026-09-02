import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/frame_motion.dart';

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
  group('sample', () {
    test('produces a grid x grid signature whatever the source size', () {
      final plane = _plane(64, 48, (x, y) => x + y);
      expect(FrameMotion.sample(plane, 64, 48, grid: 32).length, 32 * 32);
      expect(FrameMotion.sample(plane, 64, 48, grid: 8).length, 8 * 8);
    });

    test('honours a padded row stride', () {
      // Real data is 3 wide, padded to stride 4. The padding byte must never
      // reach the signature.
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
        FrameMotion.sample(padded, 3, 3, rowStride: 4, grid: 3),
        FrameMotion.sample(tight, 3, 3, grid: 3),
      );
    });

    test('centerFraction ignores noise confined to the edges', () {
      const size = 40;
      bool isEdge(int x, int y) =>
          x < 6 || y < 6 || x >= size - 6 || y >= size - 6;

      final calm = _plane(size, size, (_, __) => 100);
      final noisyEdges = _plane(size, size, (x, y) => isEdge(x, y) ? 255 : 100);

      // Cropped to the centre, the two frames are indistinguishable.
      expect(
        FrameMotion.sample(noisyEdges, size, size, centerFraction: 0.5),
        FrameMotion.sample(calm, size, size, centerFraction: 0.5),
      );
      // Over the whole plane they are not.
      expect(
        FrameMotion.sample(noisyEdges, size, size),
        isNot(FrameMotion.sample(calm, size, size)),
      );
    });

    test('throws when the buffer is shorter than the dimensions claim', () {
      expect(() => FrameMotion.sample(Uint8List(5), 4, 4), throwsArgumentError);
    });

    test('rejects a grid below one', () {
      expect(
        () => FrameMotion.sample(Uint8List(16), 4, 4, grid: 0),
        throwsArgumentError,
      );
    });
  });

  group('meanAbsoluteDifference', () {
    test('is zero for two identical signatures (a still scene)', () {
      final plane = _plane(32, 32, (x, y) => x * y);
      final a = FrameMotion.sample(plane, 32, 32);
      final b = FrameMotion.sample(plane, 32, 32);
      expect(FrameMotion.meanAbsoluteDifference(a, b), 0);
    });

    test('is maximal between a black and a white frame', () {
      final black = FrameMotion.sample(_plane(32, 32, (_, __) => 0), 32, 32);
      final white = FrameMotion.sample(_plane(32, 32, (_, __) => 255), 32, 32);
      expect(FrameMotion.meanAbsoluteDifference(black, white), 255);
    });

    test('a small shift scores far lower than a full swap', () {
      final base = _plane(32, 32, (_, __) => 100);
      final nudged = _plane(32, 32, (_, __) => 104);
      final inverted = _plane(32, 32, (_, __) => 255);
      final a = FrameMotion.sample(base, 32, 32);

      expect(
        FrameMotion.meanAbsoluteDifference(
          a,
          FrameMotion.sample(nudged, 32, 32),
        ),
        lessThan(
          FrameMotion.meanAbsoluteDifference(
            a,
            FrameMotion.sample(inverted, 32, 32),
          ),
        ),
      );
    });

    test('throws on signatures of different lengths', () {
      expect(
        () => FrameMotion.meanAbsoluteDifference(Uint8List(4), Uint8List(9)),
        throwsArgumentError,
      );
    });

    test('is zero for two empty signatures', () {
      expect(FrameMotion.meanAbsoluteDifference(Uint8List(0), Uint8List(0)), 0);
    });
  });
}
