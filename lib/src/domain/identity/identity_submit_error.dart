/// Classification of a failed identity submission into an actionable kind,
/// pure and testable (archi 4.4/5.5, AC-C13, AC-C31).
///
/// The client branches on a stable identifier, never on a message: the message
/// is prose the user reads, the kind is the contract. The archi (E11) plans a
/// stable `details.code` on every refusal; the socle in this branch does not
/// emit it yet, so this classifier PREFERS `details.code` when present
/// (forward-compatible once E11 lands) and otherwise falls back to the coarse
/// HTTP status code. That fallback cannot separate the three
/// `failed-precondition` cases (account missing, pending exists, already
/// verified) on its own: until E11, they share one generic actionable message,
/// which is recorded as an open question, not hidden.
library;

enum IdentitySubmitErrorKind {
  /// The batch id was malformed or the objects were rejected by the callable.
  batchInvalid,

  /// The three objects were not found in Storage before the call.
  objectsMissing,

  /// The batch waited too long and its objects may have been purged (E12).
  batchStale,

  /// No account behind the caller: session invalid, back to auth.
  accountMissing,

  /// A file is already pending: redirect to the tracking screen.
  pendingExists,

  /// Already verified: redirect to the verified state.
  alreadyVerified,

  /// Rate limit hit; carries [IdentitySubmitError.retryAfterMs] when known.
  rateLimited,

  /// A Storage write was denied (object present, size, filename).
  storageDenied,

  /// Not authenticated: back to auth.
  unauthenticated,

  /// Network cut or user cancellation: resumable, never a success screen.
  network,

  /// Anything unmapped: a generic, non-technical retry message (U3).
  unknown,
}

class IdentitySubmitError {
  const IdentitySubmitError(this.kind, {this.retryAfterMs});

  final IdentitySubmitErrorKind kind;

  /// Server-computed delay before another attempt, for [rateLimited] only. The
  /// client never estimates it (AC-C13b): it is shown exactly as received, or
  /// omitted when the server did not provide it.
  final int? retryAfterMs;
}

/// Classifies a failure from its stable [detailsCode] (preferred) or its coarse
/// [httpCode] (fallback). [retryAfterMs] is read straight from the server.
///
/// Kept free of Firebase types so it can be unit-tested with plain values; the
/// data-layer adapter is responsible for pulling [detailsCode], [httpCode] and
/// [retryAfterMs] out of a FirebaseFunctionsException.
IdentitySubmitError classifyIdentitySubmitError({
  String? detailsCode,
  String? httpCode,
  int? retryAfterMs,
}) {
  // Stable identifier first (E11 contract), so a reworded message never
  // reroutes the flow.
  switch (detailsCode) {
    case 'IDENTITY_BATCH_INVALID':
      return const IdentitySubmitError(IdentitySubmitErrorKind.batchInvalid);
    case 'IDENTITY_OBJECTS_MISSING':
      return const IdentitySubmitError(IdentitySubmitErrorKind.objectsMissing);
    case 'IDENTITY_BATCH_STALE':
      return const IdentitySubmitError(IdentitySubmitErrorKind.batchStale);
    case 'IDENTITY_ACCOUNT_MISSING':
      return const IdentitySubmitError(IdentitySubmitErrorKind.accountMissing);
    case 'IDENTITY_PENDING_EXISTS':
      return const IdentitySubmitError(IdentitySubmitErrorKind.pendingExists);
    case 'IDENTITY_ALREADY_VERIFIED':
      return const IdentitySubmitError(IdentitySubmitErrorKind.alreadyVerified);
    case 'IDENTITY_RATE_LIMITED':
      return IdentitySubmitError(
        IdentitySubmitErrorKind.rateLimited,
        retryAfterMs: retryAfterMs,
      );
  }

  // Fallback on the HTTP status code the socle emits today.
  switch (httpCode) {
    case 'resource-exhausted':
      return IdentitySubmitError(
        IdentitySubmitErrorKind.rateLimited,
        retryAfterMs: retryAfterMs,
      );
    case 'unauthenticated':
      return const IdentitySubmitError(IdentitySubmitErrorKind.unauthenticated);
    case 'permission-denied':
      return const IdentitySubmitError(IdentitySubmitErrorKind.storageDenied);
    case 'invalid-argument':
      return const IdentitySubmitError(IdentitySubmitErrorKind.batchInvalid);
    case 'unavailable':
    case 'cancelled':
    case 'deadline-exceeded':
      return const IdentitySubmitError(IdentitySubmitErrorKind.network);
    case 'failed-precondition':
      // Ambiguous without E11: account-missing, pending-exists and
      // already-verified all land here. Treated as pendingExists is wrong for
      // two of three, so it stays unknown and the screen shows the generic
      // "check your status" message. Open question O-1 in the report.
      return const IdentitySubmitError(IdentitySubmitErrorKind.unknown);
  }

  return const IdentitySubmitError(IdentitySubmitErrorKind.unknown);
}
