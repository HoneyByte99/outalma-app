/// Public identity state of a provider, as any client may read it.
///
/// Two values only, and the third state is the ABSENCE of the document that
/// carries them: a provider who never submitted, whose file was rejected, or
/// whose verification was revoked all look identical from outside. That is
/// deliberate (spec section 5): a refusal is not public information, and the
/// only public sanction in this product is suspension.
enum IdentityTrustStatus {
  pending('pending'),
  verified('verified');

  const IdentityTrustStatus(this.value);

  final String value;

  /// Parses the stored value, returning null for anything unknown.
  ///
  /// Returning null rather than throwing is what keeps an unexpected value from
  /// becoming a false badge: an unreadable state reads as "not verified", never
  /// as "verified". A trust signal fails closed.
  static IdentityTrustStatus? fromString(String? raw) {
    for (final status in IdentityTrustStatus.values) {
      if (status.value == raw) return status;
    }
    return null;
  }
}
