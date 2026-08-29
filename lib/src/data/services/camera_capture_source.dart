import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../application/identity/capture_source.dart' as seam;

/// The real [seam.IdentityCaptureSource]: `camera` for the frames and the JPEG,
/// `google_mlkit_face_detection` for the liveness observations (archi 5.3).
///
/// This is the thin adapter the architecture keeps OUT of coverage, on the same
/// precedent as the server's `cloudVisionExtractor`: it can only be exercised on
/// a real device (the simulator has no camera, the Android virtual camera never
/// crosses a liveness challenge), so its behaviour is qualified on the phone
/// pass, not in a VM test. Everything that CAN be tested was pushed into pure
/// helpers behind the seam (`laplacianVariance`, `LivenessChallenge`,
/// `evaluateCaptureWindow`, the deposit service).
///
/// TO VERIFY ON DEVICE (archi E8, C2): the live preview render, the exact luma
/// plane layout per platform, the ML Kit byte assembly per platform, and the
/// bounded delay between the frontal return and the shutter.
class CameraCaptureSource implements seam.IdentityCaptureSource {
  CameraCaptureSource();

  CameraController? _controller;
  FaceDetector? _faceDetector;

  /// Kept so [resumeStream] can re-attach the frame handler without reopening
  /// the camera; it is otherwise only a parameter of [start].
  CameraDescription? _description;

  StreamController<seam.LumaFrame>? _luma;
  StreamController<seam.FaceObservation>? _faces;

  /// Frame-count clock, kept ONLY for the liveness channel: its thresholds
  /// (15 s challenge, 1 s shutter window) were calibrated against it. Moving
  /// them to real time would tighten an anti-fraud path this increment does not
  /// open. The two clocks never meet in one consumer: the document screen reads
  /// only the luma channel, the selfie screen only the face channel.
  int _frameClockMs = 0;

  /// Real elapsed time, feeding [seam.LumaFrame.timestampMs] for the shutter.
  final Stopwatch _clock = Stopwatch();

  bool _detecting = false;

  @override
  Future<seam.CameraPermissionState> requestPermission() async {
    // The camera plugin surfaces the OS permission at initialize() time as a
    // CameraException; there is no separate query. We probe with the back lens
    // and map the exception codes. availableCameras() failing or empty means no
    // usable camera at all.
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      return seam.CameraPermissionState.unavailable;
    }
    if (cameras.isEmpty) return seam.CameraPermissionState.unavailable;

    try {
      final probe = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await probe.initialize();
      await probe.dispose();
      return seam.CameraPermissionState.granted;
    } on CameraException catch (e) {
      return _mapPermission(e.code);
    }
  }

  seam.CameraPermissionState _mapPermission(String code) {
    switch (code) {
      case 'CameraAccessDenied':
        return seam.CameraPermissionState.denied;
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return seam.CameraPermissionState.permanentlyDenied;
      default:
        return seam.CameraPermissionState.unavailable;
    }
  }

  @override
  Future<void> start(seam.CameraLensDirection lens) async {
    final target = lens == seam.CameraLensDirection.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      throw const seam.CaptureUnavailable('no camera list');
    }
    if (cameras.isEmpty) throw const seam.CaptureUnavailable('no camera');
    final description = cameras.firstWhere(
      (c) => c.lensDirection == target,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      // veryHigh is 1920 on the long side: a reported CIBLE deviation from the
      // 1600 target (E10/E16), well under the 5 MB Storage cap (P3).
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw seam.CaptureUnavailable(e.code);
    }
    _controller = controller;
    _description = description;
    _luma = StreamController<seam.LumaFrame>.broadcast();
    _faces = StreamController<seam.FaceObservation>.broadcast();
    _frameClockMs = 0;
    _clock
      ..reset()
      ..start();

    if (target == CameraLensDirection.front) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
      );
    }

    await controller.startImageStream((image) => _onFrame(image, description));
  }

  void _onFrame(CameraImage image, CameraDescription description) {
    _frameClockMs += 33; // ~30 fps monotonic clock for the liveness timeout.

    // Luma channel: plane 0 of a yuv420 image is the Y plane.
    final plane0 = image.planes.first;
    _luma?.add(
      seam.LumaFrame(
        luma: plane0.bytes,
        width: image.width,
        height: image.height,
        rowStride: plane0.bytesPerRow,
        timestampMs: _clock.elapsedMilliseconds,
      ),
    );

    // Face channel, front lens only, one detection at a time (drop frames while
    // busy so ML Kit never queues up).
    final detector = _faceDetector;
    if (detector == null || _detecting) return;
    final input = _toInputImage(image, description);
    if (input == null) return;
    _detecting = true;
    detector
        .processImage(input)
        .then((faces) {
          double yaw = 0;
          if (faces.length == 1) yaw = faces.first.headEulerAngleY ?? 0;
          _faces?.add(
            seam.FaceObservation(
              faceCount: faces.length,
              yawAngleDeg: yaw,
              timestampMs: _frameClockMs,
            ),
          );
        })
        .whenComplete(() => _detecting = false);
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    final rotation = InputImageRotationValue.fromRawValue(
      description.sensorOrientation,
    );
    if (rotation == null) return null;
    final format = defaultTargetPlatform == TargetPlatform.iOS
        ? InputImageFormat.yuv420
        : InputImageFormat.nv21;

    final builder = BytesBuilder();
    for (final plane in image.planes) {
      builder.add(plane.bytes);
    }
    return InputImage.fromBytes(
      bytes: builder.toBytes(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  Stream<seam.LumaFrame> lumaFrames() => _luma?.stream ?? const Stream.empty();

  @override
  Stream<seam.FaceObservation> faceObservations() =>
      _faces?.stream ?? const Stream.empty();

  @override
  Future<seam.CapturedImage> capture() async {
    final controller = _controller;
    if (controller == null) {
      throw const seam.CaptureUnavailable('not started');
    }
    // Default sequence (archi 5.3): stop the stream, THEN shoot, so we never
    // depend on takePicture() during startImageStream(), which is not universal
    // on entry-level Android.
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    final file = await controller.takePicture();
    final bytes = await file.readAsBytes();
    // An ID card must never linger in the app cache: delete the temp file the
    // moment its bytes are in memory (archi 5.3, a mutated guard T3).
    try {
      await File(file.path).delete();
    } catch (_) {
      // Best effort; the temp sweep on flow entry/exit is the backstop.
    }
    return seam.CapturedImage(bytes);
  }

  @override
  Future<void> resumeStream() async {
    final controller = _controller;
    final description = _description;
    if (controller == null || description == null) {
      throw const seam.CaptureUnavailable('not started');
    }
    if (controller.value.isStreamingImages) return;
    try {
      await controller.startImageStream(
        (image) => _onFrame(image, description),
      );
    } on CameraException catch (e) {
      // Restarting a stream after takePicture() is not universal on
      // entry-level Android. The screen falls back rather than freezing.
      throw seam.CaptureUnavailable(e.code);
    }
  }

  @override
  Future<void> stop() async {
    // Everything this method owns is read and cleared SYNCHRONOUSLY, before
    // the first await. A page's dispose() fires stop() without awaiting it
    // while the next page is already bootstrapping, so a tail that still held
    // these fields could close the stream the NEW epoch just opened, or stop
    // its clock: the hold would then never elapse and the automatic shutter
    // would silently degrade to the manual fallback.
    final controller = _controller;
    final faceDetector = _faceDetector;
    final luma = _luma;
    final faces = _faces;
    _controller = null;
    _description = null;
    _faceDetector = null;
    _luma = null;
    _faces = null;
    _clock.stop();
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {
        // ignore: already stopped or disposed.
      }
      await controller.dispose();
    }
    await faceDetector?.close();
    await luma?.close();
    await faces?.close();
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return CameraPreview(controller);
  }
}
