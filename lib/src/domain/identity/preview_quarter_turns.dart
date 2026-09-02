/// How many quarter turns take the luma plane into the preview's space.
///
/// This is a PURE SELECTOR and not a line inside the camera adapter, and that is
/// the whole point of the file. The adapter is kept out of coverage by
/// architecture decision (`camera_capture_source.dart`), so a guard living there
/// is covered by no test at all. The repo already made this call once, for
/// `selectCaptureSource` in `capture_selection.dart`, whose doc block says the
/// same thing: breaking the guard has to break a test.
///
/// For the same reason the platform arrives as a BOOLEAN. `domain/` is pure Dart
/// (CLAUDE.md, `.claude/rules/architecture-boundaries.md`) and `TargetPlatform`
/// comes from `package:flutter/foundation.dart`; `selectCaptureSource` takes
/// `bool isWeb` for exactly this reason. The adapter translates
/// `defaultTargetPlatform` on its way in.
///
/// The two values are derived from the plugin sources, not guessed:
///
/// - **iOS: always 0.** The preview texture and the Dart image stream are
///   physically the SAME buffer. `DefaultCamera.swift` hands the same
///   `CMSampleBufferGetImageBuffer` to `latestPixelBuffer` (what the texture
///   shows) and to `handleSampleBufferStreaming` (what Dart receives). Nothing
///   can rotate one relative to the other, whatever the device orientation and
///   whatever `sensorOrientation` reports.
/// - **Android: `sensorOrientation / 90`.** The analysis buffer arrives in raw
///   sensor orientation, because `setOutputImageRotationEnabled` is never called
///   anywhere in `camera_android_camerax`, while the preview is rotated for
///   display by `RotatedPreviewDelegate`.
///
/// TO VERIFY ON DEVICE: the Android SIGN. The magnitude is settled, the
/// direction is not, and it is a one-line change here rather than anywhere else.
/// The Android value also rests on the display rotation being 0, which the UI
/// portrait lock is expected but not proven to pin: if the phone pass shows a
/// contour rotated by two quarter turns, the fix is to take the plugin's own
/// reported `deviceOrientation` as a third input, which is the value
/// `CameraPreview` itself uses for its `RotatedBox`.
library;

/// Quarter turns from luma-plane space to preview space, 0 to 3.
///
/// [sensorOrientation] is the camera's reported sensor orientation in degrees
/// (0, 90, 180 or 270). Values off the quadrant are rounded to the nearest one
/// rather than rejected: a camera that reports something unexpected must still
/// give a usable preview, and refusing here would take out the whole capture
/// screen for a cosmetic overlay.
int previewQuarterTurns({required bool isIOS, required int sensorOrientation}) {
  if (isIOS) return 0;
  final quadrant = (sensorOrientation / 90).round();
  return ((quadrant % 4) + 4) % 4;
}
