import '../enums/identity_status.dart';

/// The distinct renders of the status screen (design section 7), reduced to a
/// pure enum so the mapping is testable off the VM (AC-C16).
///
/// A refused and a revoked file both offer a fresh attempt, but they are two
/// distinct renders (different title and body), so they stay two values. The
/// 4th and later refusals carry the priority mention, hence a value of their
/// own. "Too many recent submissions" is NOT here: it is driven by the
/// server-returned deadline persisted at deposit time, not by the file status,
/// and belongs to the deposit surface (design section 3).
enum IdentityStatusView {
  /// No file, or a file erased: the badge is offered.
  notVerified,

  /// A file is under review; no second submission is possible (AC-C19).
  pending,

  /// The file was approved; no path to a new deposit (AC-C18).
  verified,

  /// Refused on attempts 1 to 3: the reviewer's reason, plus a fresh attempt.
  rejected,

  /// Refused on the 4th or later attempt: reason, plus the priority mention.
  rejectedPriority,

  /// Verification was revoked: the reason, plus a fresh attempt.
  revoked;

  /// Whether this render offers a path to start (or restart) a capture.
  bool get offersCapture =>
      this == IdentityStatusView.notVerified ||
      this == IdentityStatusView.rejected ||
      this == IdentityStatusView.rejectedPriority ||
      this == IdentityStatusView.revoked;
}

/// Maps a file status (plus attempt rank) to its distinct screen render.
///
/// Pure and total: every [IdentityStatus] maps to exactly one view, and the
/// rejected split on [attempt] is the only branch that reads it. [priority]
/// mirrors the server flag; the `attempt > 3` fallback keeps the mapping honest
/// if a server ever sets the flag differently, without recomputing the policy.
IdentityStatusView identityStatusViewOf(
  IdentityStatus status, {
  int attempt = 1,
  bool priority = false,
}) {
  return switch (status) {
    IdentityStatus.none => IdentityStatusView.notVerified,
    IdentityStatus.pending => IdentityStatusView.pending,
    IdentityStatus.approved => IdentityStatusView.verified,
    IdentityStatus.rejected =>
      (priority || attempt > 3)
          ? IdentityStatusView.rejectedPriority
          : IdentityStatusView.rejected,
    IdentityStatus.revoked => IdentityStatusView.revoked,
  };
}
