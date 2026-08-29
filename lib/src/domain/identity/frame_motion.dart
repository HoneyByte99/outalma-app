import 'dart:typed_data';

import 'center_bounds.dart';

/// Stillness detection with no native dependency, the companion of
/// [ImageSharpness] for the automatic shutter.
///
/// A sharp frame is not a steady one: a moving hand can hold focus while the
/// card slides across the frame. The automatic shutter therefore needs a second
/// signal, and the cheapest honest one is how much the scene changed since the
/// previous frame.
///
/// Comparing two full luminance planes would mean keeping a ~2 MB copy of every
/// frame. Instead each frame is reduced to a fixed 32x32 [sample] (1 KB), and
/// only those signatures are compared. Both halves are pure and take explicit
/// dimensions, so they are testable on synthetic planes without a camera.
///
/// Like the sharpness threshold, the value that turns a score into
/// moving/still is NOT decided here: it is a parameter of the capture screen,
/// calibrated on the real-phone pass and mutated as a guard (T3).
class FrameMotion {
  const FrameMotion._();

  /// Reduces the centred region of the luminance plane [luma] of an image
  /// [width] x [height] to a [grid] x [grid] signature.
  ///
  /// [luma] holds one byte per pixel in row-major order. A camera Y plane may
  /// be padded (bytesPerRow > width), in which case pass the real [rowStride].
  /// [centerFraction] bounds the region read, via [centerBounds]; it defaults to
  /// the whole image so a caller must opt into cropping.
  static Uint8List sample(
    Uint8List luma,
    int width,
    int height, {
    int? rowStride,
    int grid = 32,
    double centerFraction = 1.0,
  }) {
    if (grid < 1) {
      throw ArgumentError.value(grid, 'grid', 'must be at least 1');
    }
    final stride = rowStride ?? width;
    if (width < 1 || height < 1) return Uint8List(0);
    if (luma.length < stride * (height - 1) + width) {
      throw ArgumentError(
        'luma is too short for ${width}x$height (stride $stride)',
      );
    }

    final bounds = centerBounds(width, height, centerFraction);
    final out = Uint8List(grid * grid);
    for (var gy = 0; gy < grid; gy++) {
      final y = bounds.top + (gy * bounds.height) ~/ grid;
      final row = y * stride;
      for (var gx = 0; gx < grid; gx++) {
        final x = bounds.left + (gx * bounds.width) ~/ grid;
        out[gy * grid + gx] = luma[row + x];
      }
    }
    return out;
  }

  /// Mean absolute difference between two signatures of the same length.
  ///
  /// 0 means the scene did not change at all between the two frames. Two
  /// signatures of different lengths cannot be compared and are a programming
  /// error, not a still scene, so this throws rather than returning 0.
  static double meanAbsoluteDifference(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      throw ArgumentError(
        'signatures of different lengths (${a.length} and ${b.length})',
      );
    }
    if (a.isEmpty) return 0;

    var total = 0;
    for (var i = 0; i < a.length; i++) {
      total += (a[i] - b[i]).abs();
    }
    return total / a.length;
  }
}
