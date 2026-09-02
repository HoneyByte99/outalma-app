/// The observability ports the QA scenarios asked for before any code existed
/// (archi 5.1, P-OBS-C5/C6/C8). Each is a thin interface so a spy can stand in
/// for Storage, the callable and the batch-id generator in a test.
library;

import 'dart:typed_data';

/// Uploads one object to Storage. The signature carries [contentType] on
/// purpose (P-OBS-C5): the Storage rule requires `contentType.matches('image/.*')`
/// and `putData` without metadata yields `application/octet-stream`, i.e. a
/// silent `permission-denied` a counter-only spy would miss.
abstract interface class IdentityUploadPort {
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });
}

/// Result of a successful `submitIdentityVerification` call.
class IdentitySubmitOutcome {
  const IdentitySubmitOutcome({required this.alreadySubmitted});

  /// The callable returned `{alreadySubmitted: true}`: a replay of a batch that
  /// already landed. Treated as a replay, never as a fresh success (AC-C12).
  final bool alreadySubmitted;
}

/// Calls `submitIdentityVerification({batchId})`. Implementations translate a
/// `FirebaseFunctionsException` into an [IdentitySubmitError] (via
/// `classifyIdentitySubmitError`) and throw it, so the UI branches on a stable
/// kind and never on Firebase types.
abstract interface class IdentitySubmitPort {
  Future<IdentitySubmitOutcome> submit({required String batchId});
}

/// Produces a fresh batch id for every capture attempt (P-OBS-C8). Injectable
/// so a test can force a known id and prove the replay handling of AC-C12.
abstract interface class BatchIdGenerator {
  String generate();
}
