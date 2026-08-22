/// Batch-id rules, mirrored from the server contract (archi 3, spec section 4).
///
/// The callable validates the id as 8 to 64 characters of `[A-Za-z0-9_-]` and
/// reconstructs the Storage prefix itself (`identity_verification.ts:234`), so
/// the client generates the id and never a path. Keeping the predicate pure and
/// here lets a test prove the generator honours the contract without a Firebase
/// round-trip.
library;

final RegExp _batchIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

/// Whether [value] is a batch id the callable would accept.
bool isValidBatchId(String value) => _batchIdPattern.hasMatch(value);
