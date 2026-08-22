/// The vocabulary of an identity verification file, mirrored from the server
/// (archi 3, spec section 5). English in storage, as everywhere in this repo.
///
/// [none] is the absence of any file, not a stored value: a provider who never
/// started, or whose file was erased. The status screen renders one distinct
/// state per value (AC-C16), and any unknown string coming back from the server
/// falls to [none] so a future status can never blank the screen.
enum IdentityStatus {
  none,
  pending,
  approved,
  rejected,
  revoked;

  static IdentityStatus fromString(String? value) {
    return switch (value) {
      'pending' => IdentityStatus.pending,
      'approved' => IdentityStatus.approved,
      'rejected' => IdentityStatus.rejected,
      'revoked' => IdentityStatus.revoked,
      _ => IdentityStatus.none,
    };
  }

  /// A provider with this status may start a new capture attempt. Approved and
  /// pending files have no path to a second submission (AC-C18, AC-C19); the
  /// others do.
  bool get canSubmit =>
      this == IdentityStatus.none ||
      this == IdentityStatus.rejected ||
      this == IdentityStatus.revoked;
}
