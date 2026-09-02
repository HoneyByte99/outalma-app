import 'dart:typed_data';

import '../../application/identity/document_text_detector.dart';

/// A fully drivable [DocumentTextDetector] for tests and the fake-capture
/// dart-define. It never touches ML Kit, so it runs under `flutter test`.
///
/// [result] is what [detect] returns; a test flips it to drive the "no readable
/// text" refusal and the readable-document accept path. [detectCount] proves the
/// gate actually runs the check (and runs it on the "send anyway" path too).
class FakeDocumentTextDetector implements DocumentTextDetector {
  FakeDocumentTextDetector({this.result = _readable});

  static const DocumentTextResult _readable = DocumentTextResult(
    hasText: true,
    blockCount: 3,
  );

  /// The result [detect] returns; mutable so a test can change it mid-flow.
  DocumentTextResult result;

  int detectCount = 0;
  int disposeCount = 0;
  Uint8List? lastBytes;

  @override
  Future<DocumentTextResult> detect(Uint8List jpegBytes) async {
    detectCount++;
    lastBytes = jpegBytes;
    return result;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}
