/// The downsampled luminance grid the document edge detector reads.
///
/// Working the full plane would be absurd here: the analysis stream runs at
/// `ResolutionPreset.veryHigh`, so a frame is around 1920x1080 and a per-pixel
/// pass costs about two million reads. The detector only needs where the
/// gradients are, not their exact pixel, so it reads a small grid instead.
///
/// Why this is NOT `FrameMotion.sample`, which already reduces a plane:
///
/// - that one takes a SINGLE pixel per cell, which is enough for a motion
///   signature but aliases badly at 20x decimation, and a Sobel computed on
///   aliased samples is noise, not an edge;
/// - it is square (one `grid` value), which would distort the aspect ratio the
///   detector scores against;
/// - and changing it is not an option: it would silently move the meaning of
///   `motionThreshold` and of its ten tests.
///
/// So the grid is DERIVED from the frame rather than fixed. A hardcoded 96x54
/// would give 11x35 pixel cells on a portrait plane (iOS delivers the stream
/// already display-oriented), i.e. a 3x anisotropic Sobel whose column and row
/// profiles mean nothing, on a platform the budget grid marks HARD.
library;

import 'dart:typed_data';

/// A [longSide] x derived grid of average luminance, plus its real dimensions.
///
/// [cells] is row-major, `rows * cols` bytes. [cols] and [rows] are what the
/// caller must pass on to the detector: they are not knowable in advance, being
/// derived from the frame so the cells stay near-square in either plane
/// orientation.
typedef LumaGridSample = ({Uint8List cells, int cols, int rows});

class LumaGrid {
  const LumaGrid._();

  /// Reduces the WHOLE luminance plane [luma] of a [width] x [height] frame to
  /// a grid whose long side is [longSide] cells.
  ///
  /// The whole plane, not a centred window: a card can sit anywhere in frame,
  /// and cropping the periphery would hide the very edge being looked for.
  /// That is the opposite choice from the two existing measures, which read
  /// `centerBounds` on purpose.
  ///
  /// Each cell is the mean of a [samplesPerCell] x [samplesPerCell] box of
  /// ADJACENT pixels centred on the cell, which is what buys the anti-aliasing
  /// that point sampling does not have. Spreading the samples across the cell
  /// instead would still be a decimation, and would still alias: on a period-2
  /// checkerboard every evenly spaced position lands on the same phase.
  /// [samplesPerCell] of 1 degrades to point sampling on purpose, so a test can
  /// show the difference. [luma] holds one byte per pixel in row-major order; a
  /// camera Y plane may be padded (bytesPerRow > width), in which case pass the
  /// real [rowStride].
  ///
  /// Returns an empty sample for a degenerate frame rather than throwing, so a
  /// stream that delivers a 0-sized plane leaves the detector on its "unknown"
  /// path instead of crashing the capture screen.
  static LumaGridSample sample(
    Uint8List luma,
    int width,
    int height, {
    int? rowStride,
    int longSide = 96,
    int samplesPerCell = 3,
  }) {
    if (longSide < 1) {
      throw ArgumentError.value(longSide, 'longSide', 'must be at least 1');
    }
    if (samplesPerCell < 1) {
      throw ArgumentError.value(
        samplesPerCell,
        'samplesPerCell',
        'must be at least 1',
      );
    }
    final stride = rowStride ?? width;
    if (width < 1 || height < 1) {
      return (cells: Uint8List(0), cols: 0, rows: 0);
    }
    if (luma.length < stride * (height - 1) + width) {
      throw ArgumentError(
        'luma is too short for ${width}x$height (stride $stride)',
      );
    }

    final (cols, rows) = gridFor(width, height, longSide);
    final cells = Uint8List(cols * rows);

    for (var gy = 0; gy < rows; gy++) {
      // Source rectangle of this cell row, computed from the cell index rather
      // than accumulated, so rounding never drifts across the plane.
      final y0 = (gy * height) ~/ rows;
      final y1 = ((gy + 1) * height) ~/ rows;
      final cellHeight = (y1 - y0) < 1 ? 1 : (y1 - y0);

      for (var gx = 0; gx < cols; gx++) {
        final x0 = (gx * width) ~/ cols;
        final x1 = ((gx + 1) * width) ~/ cols;
        final cellWidth = (x1 - x0) < 1 ? 1 : (x1 - x0);

        // A CONTIGUOUS box at the centre of the cell, not samples spread across
        // it. Spread samples are a decimation, and a decimation aliases: on a
        // period-2 checkerboard, evenly spaced positions all land on the same
        // phase and the "average" comes back as a hard 0 or 255, which is the
        // exact failure this class exists to avoid. Adjacent pixels cannot do
        // that, so a small contiguous box is a real low-pass.
        final cx = x0 + cellWidth ~/ 2;
        final cy = y0 + cellHeight ~/ 2;
        final reach = samplesPerCell ~/ 2;

        var total = 0;
        var count = 0;
        for (var dy = -reach; dy <= reach; dy++) {
          final y = (cy + dy).clamp(0, height - 1);
          final row = y * stride;
          for (var dx = -reach; dx <= reach; dx++) {
            final x = (cx + dx).clamp(0, width - 1);
            total += luma[row + x];
            count++;
          }
        }
        cells[gy * cols + gx] = total ~/ count;
      }
    }

    return (cells: cells, cols: cols, rows: rows);
  }

  /// The grid dimensions a [width] x [height] frame maps onto, long side first.
  ///
  /// Exposed because the detector's minimum-size rule is stated against these
  /// derived numbers, not against [longSide].
  static (int cols, int rows) gridFor(int width, int height, int longSide) {
    if (width < 1 || height < 1) return (0, 0);
    if (width >= height) {
      final rows = (longSide * height / width).round();
      return (longSide, rows < 1 ? 1 : rows);
    }
    final cols = (longSide * width / height).round();
    return (cols < 1 ? 1 : cols, longSide);
  }
}
