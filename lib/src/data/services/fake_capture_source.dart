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

  /// The bytes [capture] returns.
  Uint8List captureBytes;

  final StreamController<LumaFrame> _luma =
      StreamController<LumaFrame>.broadcast();
  final StreamController<FaceObservation> _faces =
      StreamController<FaceObservation>.broadcast();

  bool _started = false;
  int captureCount = 0;
  int stopCount = 0;

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
  Future<void> stop() async {
    stopCount++;
    _started = false;
  }

  @override
  Widget buildPreview() =>
      const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand());

  bool get isStreaming => _started;

  /// Pushes a luma frame to the sharpness channel.
  void emitLuma(LumaFrame frame) {
    if (!_luma.isClosed) _luma.add(frame);
  }

  /// Pushes a face observation to the liveness channel.
  void emitFace(FaceObservation observation) {
    if (!_faces.isClosed) _faces.add(observation);
  }

  Future<void> dispose() async {
    await _luma.close();
    await _faces.close();
  }
}
