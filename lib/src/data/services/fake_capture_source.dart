import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../application/identity/capture_source.dart';

/// A fully drivable [IdentityCaptureSource] (archi 5.2, P-OBS-C1/C2/C3).
///
/// It never touches a camera, so it runs under `flutter test` and behind the
/// `OUTALMA_FAKE_CAPTURE` dart-define against the emulators. The two channels
/// are independent: [emitLuma] feeds the sharpness check, [emitFace] feeds the
/// liveness machine, and [captureBytes] is what [capture] returns. Permission
/// and availability are set fields so a test can drive the denied and
/// unavailable states without a device.
class FakeCaptureSource implements IdentityCaptureSource {
  FakeCaptureSource({
    this.permission = CameraPermissionState.granted,
    this.available = true,
    Uint8List? captureBytes,
  }) : captureBytes = captureBytes ?? Uint8List.fromList(const [1, 2, 3]);

  /// The state [requestPermission] returns.
  CameraPermissionState permission;

  /// When false, [start] throws [CaptureUnavailable] like a device with no
  /// usable camera.
  bool available;

  /// When true, [resumeStream] throws, like the entry-level Android devices
  /// where restarting a stream after takePicture() does not work.
  bool failResume = false;

  /// The bytes [capture] returns.
  Uint8List captureBytes;

  final StreamController<LumaFrame> _luma =
      StreamController<LumaFrame>.broadcast();
  final StreamController<FaceObservation> _faces =
      StreamController<FaceObservation>.broadcast();

  bool _started = false;
  int captureCount = 0;
  int stopCount = 0;
  int resumeCount = 0;

  @override
  Future<CameraPermissionState> requestPermission() async => permission;

  @override
  Future<void> start(CameraLensDirection lens) async {
    if (!available) throw const CaptureUnavailable('no camera');
    _started = true;
  }

  @override
  Stream<LumaFrame> lumaFrames() => _luma.stream;

  @override
  Stream<FaceObservation> faceObservations() => _faces.stream;

  @override
  Future<CapturedImage> capture() async {
    captureCount++;
    _started = false;
    return CapturedImage(captureBytes);
  }

  @override
  Future<void> resumeStream() async {
    resumeCount++;
    if (failResume) throw const CaptureUnavailable('resume refused');
    _started = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _started = false;
  }

  /// The geometry [previewGeometry] reports. Null by default, so a test that
  /// says nothing about geometry gets a screen that draws no contour, exactly
  /// like a source that has not started yet.
  PreviewGeometry? geometry;

  @override
  PreviewGeometry? get previewGeometry => geometry;

  /// A preview of the SAME SHAPE as the real one, not a bare box.
  ///
  /// This is load-bearing for the contour tests. `CameraPreview` wraps itself in
  /// an `AspectRatio` around a `Stack(fit: StackFit.expand)`, and the whole
  /// projection rests on that `AspectRatio` being INERT under the page's own
  /// expanded Stack, so the texture is stretched full-bleed. A fake that
  /// returned a bare `SizedBox.expand()` would make "the contour rect equals
  /// the preview rect" true by construction and the test would prove nothing,
  /// whatever a future version of `camera` did to that tree.
  ///
  /// Encodes the layout tree of camera 0.12.0+2. The opaque ground is kept:
  /// other tests screenshot this screen.
  @override
  Widget buildPreview() {
    return AspectRatio(
      aspectRatio: previewAspectRatio,
      child: const Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Color(0xFF000000), child: SizedBox.expand()),
        ],
      ),
    );
  }

  /// The ratio the faked `CameraPreview` imposes. 9/16 is what a portrait
  /// preview of a 16:9 stream reports.
  double previewAspectRatio = 9 / 16;

  bool get isStreaming => _started;

  /// Pushes a luma frame to the sharpness channel.
  ///
  /// A STOPPED source emits nothing, exactly like the real one: [capture]
  /// leaves the stream stopped until [resumeStream] restarts it. Without this
  /// guard a test could not tell a working resume from an empty one, since
  /// frames would keep arriving either way, and neutralising the resume would
  /// turn no test red.
  void emitLuma(LumaFrame frame) {
    if (!_started || _luma.isClosed) return;
    _luma.add(frame);
  }

  /// Pushes a face observation to the liveness channel. Stopped means silent,
  /// for the same reason as [emitLuma].
  void emitFace(FaceObservation observation) {
    if (!_started || _faces.isClosed) return;
    _faces.add(observation);
  }

  Future<void> dispose() async {
    await _luma.close();
    await _faces.close();
  }
}
