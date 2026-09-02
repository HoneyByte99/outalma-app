import 'package:flutter/widgets.dart';

import '../../application/identity/capture_source.dart';

/// Web-safe placeholder for [CameraCaptureSource] (archi 5.3 web isolation).
///
/// `camera` and especially `google_mlkit_face_detection` have no web support, so
/// the real adapter is imported only under `dart.library.io`. On web this stub
/// is compiled instead: the capture entry is never offered there
/// (`captureAvailable(isWeb: true)` is false, AC-C04), and if anything ever did
/// reach it, every method fails loudly rather than pulling a mobile-only plugin
/// into the web bundle.
class CameraCaptureSource implements IdentityCaptureSource {
  CameraCaptureSource();

  Never _unsupported() =>
      throw UnsupportedError('Identity capture is mobile-only (AC-C04).');

  @override
  Future<CameraPermissionState> requestPermission() async =>
      CameraPermissionState.unavailable;

  @override
  Future<void> start(CameraLensDirection lens) async => _unsupported();

  @override
  Stream<LumaFrame> lumaFrames() => const Stream.empty();

  @override
  Stream<FaceObservation> faceObservations() => const Stream.empty();

  @override
  Future<CapturedImage> capture() async => _unsupported();

  @override
  Future<void> resumeStream() async => _unsupported();

  @override
  Future<void> stop() async {}

  @override
  Widget buildPreview() => const SizedBox.expand();
}
