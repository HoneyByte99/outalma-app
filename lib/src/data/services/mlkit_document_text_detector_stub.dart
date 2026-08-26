import 'dart:typed_data';

import '../../application/identity/document_text_detector.dart';

/// Web-safe placeholder for [MlkitDocumentTextDetector].
///
/// `google_mlkit_text_recognition` has no web support, so the real detector is
/// imported only under `dart.library.io`. The capture flow is mobile-only
/// (AC-C04) and never reaches here on web; this stub keeps the plugin out of the
/// web bundle and, on the impossible path, reports "no text checked" (treated as
/// no text) rather than pretending a document was seen.
class MlkitDocumentTextDetector implements DocumentTextDetector {
  MlkitDocumentTextDetector();

  @override
  Future<DocumentTextResult> detect(Uint8List jpegBytes) async =>
      DocumentTextResult.none;

  @override
  Future<void> dispose() async {}
}
