import '../enums/price_type.dart';

/// Bounds for a single billing mode, read from `config/pricing`.
class PricingModeBounds {
  const PricingModeBounds({
    required this.min,
    required this.max,
    required this.extraBonusPercent,
    this.isRange = false,
  });

  /// Floor, in whole FCFA. Never moves with extra tasks (spec decision 10).
  final int min;

  /// Base ceiling, in whole FCFA, before any extra-task bonus.
  final int max;

  /// Percent added to the ceiling per extra task, as a whole integer.
  final int extraBonusPercent;

  /// The monthly mode asks for a min/max range instead of a single price.
  final bool isRange;

  factory PricingModeBounds.fromMap(Map<String, Object?> map) {
    return PricingModeBounds(
      min: (map['min'] as num).toInt(),
      max: (map['max'] as num).toInt(),
      extraBonusPercent: (map['extraBonusPercent'] as num?)?.toInt() ?? 0,
      isRange: (map['isRange'] as bool?) ?? false,
    );
  }

  /// Effective ceiling for [extraCount] extra tasks, in whole FCFA.
  ///
  /// This reproduces EXACTLY the integer arithmetic of `firestore.rules`:
  /// `price * 100 <= max * (100 + pct * n)`. Computing `max * (1 + pct/100)`
  /// in floating point would reject legitimate values (e.g. 3500 * 1.15 =
  /// 4024.999...), so the ceiling stays integer-only. Truncating division
  /// matches the rule's comparison: a price passes the rule iff it is `<=` this.
  int capFor(int extraCount) => cap(max, extraBonusPercent, extraCount);
}

/// Effective ceiling, in whole FCFA, for a base [max], a whole-integer
/// [bonusPercent] per extra task, and [extraCount] extra tasks.
///
/// Pure, side-effect free, and the single source of the ceiling formula shared
/// by the form and its tests (budget line T4).
int cap(int max, int bonusPercent, int extraCount) =>
    max * (100 + bonusPercent * extraCount) ~/ 100;

/// The pricing grid, mirroring the `config/pricing` Firestore document. The
/// form reads it once per session; the same document backs the server rule, so
/// the displayed range and the enforced range cannot drift apart.
class PricingConfig {
  const PricingConfig({
    required this.version,
    required this.currency,
    required this.boundedCategories,
    required this.maxExtraTasks,
    required this.modes,
  });

  final int version;
  final String currency;
  final List<String> boundedCategories;
  final int maxExtraTasks;
  final Map<PriceType, PricingModeBounds> modes;

  factory PricingConfig.fromMap(Map<String, Object?> map) {
    final rawModes = (map['modes'] as Map).cast<String, Object?>();
    final modes = <PriceType, PricingModeBounds>{};
    for (final entry in rawModes.entries) {
      final type = PriceType.fromString(entry.key);
      modes[type] = PricingModeBounds.fromMap(
        (entry.value as Map).cast<String, Object?>(),
      );
    }
    return PricingConfig(
      version: (map['version'] as num?)?.toInt() ?? 1,
      currency: (map['currency'] as String?) ?? 'XOF',
      boundedCategories:
          (map['boundedCategories'] as List?)?.whereType<String>().toList() ??
          const [],
      maxExtraTasks: (map['maxExtraTasks'] as num?)?.toInt() ?? 3,
      modes: modes,
    );
  }

  PricingModeBounds? boundsFor(PriceType mode) => modes[mode];

  bool isBounded(String categoryId) => boundedCategories.contains(categoryId);

  /// Cheap sanity gate against a grid mis-edited by hand in the Firebase
  /// console (spec risk R1): a floor above a ceiling, a negative bonus, or a
  /// missing bounded mode turns a silently-wrong grid into a visible error the
  /// form can surface instead of applying. It does NOT replace the deferred
  /// admin screen and creates no audit trail.
  bool get isCoherent {
    if (boundedCategories.isEmpty || maxExtraTasks < 0) return false;
    for (final mode in const [
      PriceType.hourly,
      PriceType.daily,
      PriceType.monthly,
    ]) {
      final b = modes[mode];
      if (b == null) return false;
      if (b.min <= 0 || b.max < b.min || b.extraBonusPercent < 0) return false;
    }
    return true;
  }
}
