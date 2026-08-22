import 'dart:typed_data';

/// Blur detection with no native dependency (archi 5.3, AC-C06).
///
/// The variance of the Laplacian is the classic "is this photo in focus?"
/// measure: a sharp image has strong high-frequency content, so the second
/// derivative (Laplacian) has a wide spread; a blurred one is flat, so the
/// spread collapses. We compute it on the raw luminance plane the camera
/// stream already exposes, never on a re-decoded JPEG, so the check runs
/// before anything is uploaded.
///
/// The function is pure and takes explicit dimensions, so it is testable on
/// synthetic images (a checkerboard scores high, a flat field scores zero)
/// without a camera. The threshold that turns a score into accept/reject is
/// NOT decided here: it is a parameter of the capture screen, calibrated on
/// the real-phone pass (Q2) and mutated as a guard (T3). AC-C06 asks the tests
/// to prove the mechanism and the ordering of the two thresholds, never their
/// absolute correctness.
class ImageSharpness {
  const ImageSharpness._();

  /// Variance of the 3x3 Laplacian over the luminance plane [luma] of an
  /// image [width] x [height]. Higher means sharper.
  ///
  /// [luma] holds one byte per pixel in row-major order, length at least
  /// [width] * [height]. A camera Y plane may be padded (bytesPerRow > width),
  /// in which case pass the real [rowStride] so rows are read correctly.
  ///
  /// Returns 0 for a degenerate image (no interior pixels): a 1-pixel-wide
  /// strip has no neighbours to differentiate, and reporting 0 keeps such an
  /// image on the "too blurred" side rather than crashing.
  static double laplacianVariance(
    Uint8List luma,
    int width,
    int height, {
    int? rowStride,
  }) {
    if (width < 3 || height < 3) return 0;
    final stride = rowStride ?? width;
    if (luma.length < stride * (height - 1) + width) {
      throw ArgumentError(
        'luma is too short for ${width}x$height (stride $stride)',
      );
    }

    // Single pass over the interior pixels, accumulating sum and sum of
    // squares of the Laplacian response, so variance is one final division and
    // no second array is allocated.
    double sum = 0;
    double sumSq = 0;
    var count = 0;
    for (var y = 1; y < height - 1; y++) {
      final row = y * stride;
      final rowUp = (y - 1) * stride;
      final rowDown = (y + 1) * stride;
      for (var x = 1; x < width - 1; x++) {
        // 4-neighbour Laplacian kernel: centre * 4 minus its cross neighbours.
        final lap =
            (luma[row + x] * 4) -
            luma[row + x - 1] -
            luma[row + x + 1] -
            luma[rowUp + x] -
            luma[rowDown + x];
        final v = lap.toDouble();
        sum += v;
        sumSq += v * v;
        count++;
      }
    }
    if (count == 0) return 0;
    final mean = sum / count;
    return (sumSq / count) - (mean * mean);
  }
}
