/// The gender a person declares for themself at sign-up.
///
/// Two values and only two. That is a product decision, taken deliberately: the
/// field is mandatory on both sign-up paths, there is no third value and no
/// "prefer not to say".
///
/// The DECLARED value is the only source of truth. `cniSexe`, extracted from an
/// identity document by `identity_extraction.ts`, never overwrites it: the two
/// answer different questions, and no trigger reconciles them.
enum Gender {
  male,
  female;

  /// Parses a stored value, returning null for anything that is not exactly one
  /// of the two canonical names.
  ///
  /// Deliberately NULLABLE, unlike `ActiveMode.fromString` which falls back to a
  /// default. Two reasons, both about not inventing an answer:
  ///
  ///  - Every account created before this field existed carries no value at all.
  ///    Absent has to stay absent all the way to the interface, which renders
  ///    nothing for it. A default would print a pictogram claiming a gender the
  ///    person never declared, on a public card, next to their name.
  ///  - `users` documents exported from the 2024 FlutterFlow app carry a legacy
  ///    `gender` key under the SAME name with an unknown vocabulary. Strict
  ///    matching means such a value reads as unknown and shows nothing, rather
  ///    than being coerced into one of the two answers.
  static Gender? tryParse(Object? value) {
    if (value is! String) return null;
    for (final g in Gender.values) {
      if (g.name == value) return g;
    }
    return null;
  }
}
