/// The injectable capture seam (archi 5.1/5.2, E8).
///
/// The camera and ML Kit cannot run under `flutter test` (no device, no
/// platform channels), and the iOS simulator has no camera while the Android
/// virtual camera never crosses a liveness challenge. So the whole capture
/// journey is driven through this interface: the real implementation
/// ([CameraCaptureSource]) wraps `camera` plus `google_mlkit_face_detection`,
/// and a [FakeCaptureSource] drives every path from tests and from the
/// `OUTALMA_FAKE_CAPTURE` dart-define.
///
/// The seam exposes TWO independently pilotable channels (archi P-OBS-C1/C2):
/// the raw luminance frames on one side (feed the sharpness check) and the face
/// observations on the other (feed the liveness machine). A single "make the
/// whole capture fake" channel would not let a test exercise the sharpness then
/// compression then upload chain against controlled frames.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Whether the camera can be used, injectable per archi P-OBS-C3.
enum CameraPermissionState {
  /// The user granted the camera permission.
  granted,

  /// Denied this time, but the OS may ask again.
  denied,

  /// Denied for good: the only path back is the system settings.
  permanentlyDenied,

  /// No camera on the device, or the platform cannot provide one (web).
  unavailable,
}

/// Which physical camera to open.
enum CameraLensDirection { back, front }

/// One raw frame's luminance plane, straight off the camera stream.
///
/// The camera Y plane can be padded, so [rowStride] may exceed [width]; the
/// sharpness routine reads rows with the stride. Bytes are one luma sample per
/// pixel, row-major.
///
/// [timestampMs] is REAL elapsed time since the stream started, not a frame
/// count. The automatic shutter holds the framing for a duration, and a frame
/// counter would make that duration stretch exactly where it must not: on an
/// entry-level phone whose frame rate collapses under the analysis, "800 ms"
/// counted at an assumed 30 fps would really last well over two seconds. The
/// fake drives this clock freely, so the hold is testable without a device.
class LumaFrame {
  const LumaFrame({
    required this.luma,
    required this.width,
    required this.height,
    required this.rowStride,
    required this.timestampMs,
  });

  final Uint8List luma;
  final int width;
  final int height;
  final int rowStride;
  final int timestampMs;
}

/// One face-detection observation, the only thing the liveness machine needs.
///
/// [yawAngleDeg] is the head Euler Y angle; its magnitude drives the turn and
/// the frontal return. [timestampMs] is a monotonic-ish clock the fake can
/// control so the timeout is testable without a real wall clock.
class FaceObservation {
  const FaceObservation({
    required this.faceCount,
    required this.yawAngleDeg,
    required this.timestampMs,
  });

  final int faceCount;
  final double yawAngleDeg;
  final int timestampMs;
}

/// The bytes of a captured still. Always JPEG: `takePicture()` already encodes
/// one at the chosen `ResolutionPreset`, so no extra encoder is added (E16).
class CapturedImage {
  const CapturedImage(this.jpegBytes);

  final Uint8List jpegBytes;
}

/// The capture seam. One instance drives one screen at a time: [start] opens a
/// lens and begins streaming, [capture] closes the stream then shoots (archi
/// 5.3, the default sequence that does not rely on shooting while streaming),
/// and [stop] releases the camera.
abstract interface class IdentityCaptureSource {
  /// Asks for the camera permission, returning the resulting state. Idempotent:
  /// calling it when already granted just returns [CameraPermissionState.granted].
  Future<CameraPermissionState> requestPermission();

  /// Opens [lens] and starts the frame stream. Throws [CaptureUnavailable] when
  /// no camera can be opened, so the screen can show its "camera unavailable"
  /// state rather than a raw platform error.
  Future<void> start(CameraLensDirection lens);

  /// Raw luminance frames, for the sharpness check. Empty until [start].
  Stream<LumaFrame> lumaFrames();

  /// Face observations, for the liveness machine. Empty until [start] with the
  /// front lens.
  Stream<FaceObservation> faceObservations();

  /// Stops the stream, shoots a still, reads its bytes and deletes the temp
  /// file (archi 5.3: an ID card must never linger in the app cache). The
  /// returned bytes are the only copy the flow keeps.
  Future<CapturedImage> capture();

  /// Restarts the frame stream after a [capture] whose still was REFUSED
  /// downstream, without reopening the camera.
  ///
  /// [capture] leaves the stream stopped. That was harmless while a person had
  /// to press the button again, but the automatic shutter would simply freeze
  /// there: no frames, no sharpness, no way back. This is the way back, and it
  /// is deliberately cheaper than [stop] plus [start], which reopens the device
  /// and costs about a second.
  ///
  /// Only for the refused path. After an ACCEPTED still the screen is already
  /// being torn down, and restarting a stream on a controller about to be
  /// disposed is exactly what breaks on entry-level Android.
  ///
  /// Throws [CaptureUnavailable] when the stream cannot be restarted, so the
  /// screen has a single failure contract to know.
  Future<void> resumeStream();

  /// Releases the camera and both streams. Safe to call more than once.
  Future<void> stop();

  /// The live preview widget to place under the framing overlay. Returns an
  /// empty box before [start] or when there is nothing to show (the fake, the
  /// web stub), so the screen stays platform-agnostic and testable.
  Widget buildPreview();
}

/// Thrown by [IdentityCaptureSource.start] when no camera can be opened.
class CaptureUnavailable implements Exception {
  const CaptureUnavailable([this.message]);
  final String? message;
  @override
  String toString() => 'CaptureUnavailable(${message ?? ''})';
}
