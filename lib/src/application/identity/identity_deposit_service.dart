import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';

import '../../domain/identity/identity_submit_error.dart';
import 'identity_ports.dart';

/// The three validated stills of one attempt, in capture order.
class IdentityImages {
  const IdentityImages({
    required this.recto,
    required this.verso,
    required this.selfie,
  });

  final Uint8List recto;
  final Uint8List verso;
  final Uint8List selfie;
}

/// Outcome of a deposit attempt, a sealed pair so the UI never has to read an
/// exception to branch.
sealed class IdentityDepositResult {
  const IdentityDepositResult();
}

/// The three objects uploaded and the callable accepted (or replayed).
class IdentityDepositSuccess extends IdentityDepositResult {
  const IdentityDepositSuccess({required this.alreadySubmitted});

  /// The callable reported the batch had already landed: a replay, shown as the
  /// real file state and never as a fresh success (AC-C12).
  final bool alreadySubmitted;
}

/// The deposit failed; [error] carries the stable kind the UI maps to a French
/// message (archi 5.5). Resumable: the caller retries on a fresh batch id.
class IdentityDepositFailure extends IdentityDepositResult {
  const IdentityDepositFailure(this.error);

  final IdentitySubmitError error;
}

/// Orchestrates the four steps of a deposit (archi 5.4): fresh batch id, three
/// Storage uploads under `private/identity/{uid}/{batchId}/`, then the callable.
///
/// Nothing is uploaded until all three stills are validated (E13): the caller
/// only builds an [IdentityImages] once the recap is confirmed. A partial
/// upload is left for the server-side purge (E12); the caller always restarts
/// on a new batch id.
class IdentityDepositService {
  const IdentityDepositService({
    required IdentityUploadPort upload,
    required IdentitySubmitPort submit,
    required BatchIdGenerator batchIds,
  }) : _upload = upload,
       _submit = submit,
       _batchIds = batchIds;

  final IdentityUploadPort _upload;
  final IdentitySubmitPort _submit;
  final BatchIdGenerator _batchIds;

  /// Uploads the three objects for [uid] then submits. Returns a sealed result
  /// rather than throwing, so both paths are equally explicit at the call site.
  Future<IdentityDepositResult> deposit({
    required String uid,
    required IdentityImages images,
  }) async {
    final batchId = _batchIds.generate();
    final prefix = 'private/identity/$uid/$batchId';

    try {
      // Order matters: the three objects must EXIST before the callable, which
      // rejects with invalid-argument otherwise (archi section 1).
      await _upload.upload(
        path: '$prefix/recto.jpg',
        bytes: images.recto,
        contentType: 'image/jpeg',
      );
      await _upload.upload(
        path: '$prefix/verso.jpg',
        bytes: images.verso,
        contentType: 'image/jpeg',
      );
      await _upload.upload(
        path: '$prefix/selfie.jpg',
        bytes: images.selfie,
        contentType: 'image/jpeg',
      );
    } on FirebaseException catch (_) {
      // A denied Storage write (object present, size, filename) surfaces as an
      // actionable message plus a fresh-batch retry (archi 5.5). Without this
      // branch it would reach the user as a raw error (U3).
      return const IdentityDepositFailure(
        IdentitySubmitError(IdentitySubmitErrorKind.storageDenied),
      );
    }

    try {
      final outcome = await _submit.submit(batchId: batchId);
      return IdentityDepositSuccess(alreadySubmitted: outcome.alreadySubmitted);
    } on IdentitySubmitError catch (error) {
      return IdentityDepositFailure(error);
    }
  }
}
