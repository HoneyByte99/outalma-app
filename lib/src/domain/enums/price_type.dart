enum PriceType {
  hourly,
  daily,
  monthly,
  // Legacy value. New services never use `fixed`; the one-shot pricing
  // migration rewrites every `fixed` document to `daily` (spec decision 11).
  // Kept in the enum so pre-migration documents still deserialise until the
  // migration has run everywhere, after which it can be removed.
  fixed;

  static PriceType fromString(String value) {
    return PriceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PriceType.fixed,
    );
  }
}
