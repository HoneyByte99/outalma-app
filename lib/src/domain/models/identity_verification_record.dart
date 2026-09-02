import '../enums/identity_status.dart';

/// The provider's own latest identity verification file, as it lives in
/// `identity_verifications/{id}` (archi 5.6, spec section 5).
///
/// This is the "history" side of the split described in archi 5.6: the public
/// projection (`provider_trust`) says the STATE, this record says the STORY the
/// projection cannot carry, when it was submitted, the reviewer's reason, the
/// attempt rank. The owner reads their own file directly (firestore.rules:116);
/// the internal subcollection (duplicate flag, reviewer identity) is never read
/// here (AC-C20).
///
/// Only the fields the status screen renders are mapped. The extracted CNI
/// fields are deliberately NOT modelled: the client never needs them, and not
/// reading them keeps them off the wire (AC-C15 in spirit).
class IdentityVerificationRecord {
  const IdentityVerificationRecord({
    required this.status,
    required this.attempt,
    required this.priority,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  /// The file status, mirrored from the server vocabulary.
  final IdentityStatus status;

  /// 1-based attempt rank (`attempt` on the server). The 4th and later attempts
  /// carry the priority mention (AC-C16, design section 7).
  final int attempt;

  /// Whether the server flagged this file for priority review. Derived server
  /// side from `attempt > PRIORITY_AFTER_ATTEMPTS`; mirrored, never recomputed.
  final bool priority;

  /// The reviewer's reason, shown to the provider verbatim (AC-C17). Null while
  /// pending or when no reason was recorded.
  final String? rejectionReason;

  /// When the file was submitted. Drives the "submitted on {date}" line.
  final DateTime? submittedAt;

  /// When a decision was taken. Drives the "verified since {date}" line.
  final DateTime? reviewedAt;
}
