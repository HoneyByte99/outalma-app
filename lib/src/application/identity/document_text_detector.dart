/// The injectable readable-text seam (archi 5.3 extension, AC-C06b).
///
/// The sharpness gate proves a still is IN FOCUS, never that it is a DOCUMENT: a
/// crisp photo of a wall, a hand or a cow passes it. A national ID card always
/// carries printed text, so a cheap on-device pass that asks only "is there any
/// text at all?" rejects the obvious non-documents before they are uploaded and
/// before a human ever reviews them.
///
/// The seam mirrors the capture seam: the real implementation
/// ([MlkitDocumentTextDetector]) wraps `google_mlkit_text_recognition`, and a
/// fake drives every path from tests. It NEVER returns the recognised text,
/// only whether some was found and a coarse count, so nothing readable off an ID
/// card is kept in memory a moment longer than the recogniser needs.
library;

import 'dart:typed_data';

/// The outcome of one readable-text pass over a captured still.
class DocumentTextResult {
  const DocumentTextResult({required this.hasText, required this.blockCount});

  /// Whether any text at all was recognised on the still.
  final bool hasText;

  /// How many text blocks the recogniser returned, a coarse confidence hint for
  /// the caller. Zero exactly when [hasText] is false.
  final int blockCount;

  /// The result of a still on which nothing readable was found.
  static const DocumentTextResult none = DocumentTextResult(
    hasText: false,
    blockCount: 0,
  );
}

/// Runs an on-device readable-text check over the bytes of a captured still.
abstract interface class DocumentTextDetector {
  /// Recognises text on [jpegBytes] and reports whether any was found. Returns
  /// [DocumentTextResult.none] rather than throwing when the recogniser cannot
  /// run, so a detector failure never blocks a capture on its own (the gate
  /// treats "could not check" the same as "no text", and the human review and
  /// the "send anyway" escape both remain reachable).
  Future<DocumentTextResult> detect(Uint8List jpegBytes);

  /// Releases any native recogniser held open. Safe to call more than once.
  Future<void> dispose();
}
