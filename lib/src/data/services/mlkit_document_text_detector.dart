import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../application/identity/document_text_detector.dart';

/// Real [DocumentTextDetector] backed by on-device ML Kit text recognition.
///
/// ML Kit reads an image off a file path, so the JPEG bytes are written to a
/// private temp file, recognised, then the file is deleted straight away: an ID
/// card must never linger on disk (same rule as the capture still). Nothing but
/// the presence and the block count leaves this class; the recognised text is
/// dropped with the recogniser's result object.
///
/// `Directory.systemTemp` is used rather than `path_provider`'s
/// `getTemporaryDirectory`, which fails to load `objective_c.framework` on this
/// project's iOS toolchain (same workaround as chat_page and booking_request).
class MlkitDocumentTextDetector implements DocumentTextDetector {
  MlkitDocumentTextDetector({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<DocumentTextResult> detect(Uint8List jpegBytes) async {
    File? temp;
    try {
      temp = await File(
        '${Directory.systemTemp.path}/outalma_idtext_${jpegBytes.length}_${jpegBytes.hashCode}.jpg',
      ).writeAsBytes(jpegBytes, flush: true);
      final input = InputImage.fromFilePath(temp.path);
      final recognised = await _recognizer.processImage(input);
      final blocks = recognised.blocks.length;
      final hasText = recognised.text.trim().isNotEmpty && blocks > 0;
      return DocumentTextResult(hasText: hasText, blockCount: blocks);
    } catch (_) {
      // A recogniser failure must not block the capture: report "no text" so the
      // gate keeps the human review and the "send anyway" escape reachable.
      return DocumentTextResult.none;
    } finally {
      if (temp != null) {
        try {
          await temp.delete();
        } catch (_) {
          // Best effort: a leftover temp file is a smaller risk than a throw.
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
