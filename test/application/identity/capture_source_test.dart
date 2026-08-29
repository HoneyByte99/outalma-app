import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/capture_source.dart';
import 'package:outalma_app/src/data/services/fake_capture_source.dart';

void main() {
  group('capture seam value types', () {
    test('LumaFrame keeps its plane, dimensions, stride and clock', () {
      final bytes = Uint8List.fromList(const [1, 2, 3, 4]);
      final frame = LumaFrame(
        luma: bytes,
        width: 2,
        height: 2,
        rowStride: 2,
        timestampMs: 640,
      );
      expect(frame.luma, same(bytes));
      expect(frame.width, 2);
      expect(frame.height, 2);
      expect(frame.rowStride, 2);
      expect(frame.timestampMs, 640);
    });

    test('FaceObservation keeps its count, yaw and timestamp', () {
      // Built at runtime (not const) so the constructor is exercised.
      final yaw = double.parse('27.5');
      final obs = FaceObservation(
        faceCount: 1,
        yawAngleDeg: yaw,
        timestampMs: 1234,
      );
      expect(obs.faceCount, 1);
      expect(obs.yawAngleDeg, 27.5);
      expect(obs.timestampMs, 1234);
    });

    test('CapturedImage carries its JPEG bytes', () {
      final bytes = Uint8List.fromList(const [9, 9]);
      expect(CapturedImage(bytes).jpegBytes, same(bytes));
    });

    test('CaptureUnavailable is a readable exception', () {
      expect(const CaptureUnavailable('no camera').message, 'no camera');
      expect(
        const CaptureUnavailable('no camera').toString(),
        contains('no camera'),
      );
      expect(
        const CaptureUnavailable().toString(),
        contains('CaptureUnavailable'),
      );
    });

    test('the permission and lens enums expose their full vocabulary', () {
      expect(CameraPermissionState.values, hasLength(4));
      expect(CameraLensDirection.values, hasLength(2));
    });
  });

  group('FakeCaptureSource mirrors the real stream lifecycle', () {
    LumaFrame frame() => LumaFrame(
      luma: Uint8List(4),
      width: 2,
      height: 2,
      rowStride: 2,
      timestampMs: 0,
    );

    test('a stopped source emits nothing, like the real one after capture', () {
      final source = FakeCaptureSource();
      final seen = <LumaFrame>[];
      source.lumaFrames().listen(seen.add);

      // Never started: silent.
      source.emitLuma(frame());
      expect(seen, isEmpty);
    });

    test('capture stops the stream and resumeStream restarts it', () async {
      final source = FakeCaptureSource();
      final seen = <LumaFrame>[];
      source.lumaFrames().listen(seen.add);

      await source.start(CameraLensDirection.back);
      source.emitLuma(frame());
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1));

      // capture() leaves the stream stopped: this is the freeze the automatic
      // shutter would hit without a resume.
      await source.capture();
      source.emitLuma(frame());
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1), reason: 'no frames while stopped');

      await source.resumeStream();
      source.emitLuma(frame());
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(2));
      expect(source.resumeCount, 1);
    });

    test('a refused resume leaves the source stopped', () async {
      final source = FakeCaptureSource()..failResume = true;
      final seen = <LumaFrame>[];
      source.lumaFrames().listen(seen.add);

      await source.start(CameraLensDirection.back);
      await source.capture();
      await expectLater(
        source.resumeStream(),
        throwsA(isA<CaptureUnavailable>()),
      );

      source.emitLuma(frame());
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
    });
  });
}
