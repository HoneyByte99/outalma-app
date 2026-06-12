// Regression test for the chat image size budget. The bug: web skipped
// resizing and height was unbounded, so a tall photo uploaded huge and rendered
// awkwardly. _pickImage must apply maxWidth:1024, maxHeight:1024, quality:80 on
// every platform, for both gallery and camera.

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/data/services/chat_media_service.dart';

class _MockPicker extends Mock implements ImagePicker {}

class _MockStorage extends Mock implements FirebaseStorage {}

void main() {
  setUpAll(() => registerFallbackValue(ImageSource.gallery));

  late _MockPicker picker;
  late ChatMediaService svc;

  setUp(() {
    picker = _MockPicker();
    svc = ChatMediaService(storage: _MockStorage(), picker: picker);
    // Returning null short-circuits before any Firebase Storage upload, so we
    // can assert the picker arguments without touching the network.
    when(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => null);
  });

  List<Object?> capturedArgs() => verify(
    () => picker.pickImage(
      source: captureAny(named: 'source'),
      maxWidth: captureAny(named: 'maxWidth'),
      maxHeight: captureAny(named: 'maxHeight'),
      imageQuality: captureAny(named: 'imageQuality'),
    ),
  ).captured;

  test('gallery pick is bounded to 1024×1024 @ q80', () async {
    final result = await svc.pickImageFromGallery('chat1');
    expect(result, isNull);
    expect(capturedArgs(), [ImageSource.gallery, 1024.0, 1024.0, 80]);
  });

  test('camera capture is bounded to 1024×1024 @ q80', () async {
    final result = await svc.takePhoto('chat1');
    expect(result, isNull);
    expect(capturedArgs(), [ImageSource.camera, 1024.0, 1024.0, 80]);
  });
}
