enum CategoryId {
  menage,
  plomberie,
  jardinage,
  electricite,
  peinture,
  bricolage,
  gardeEnfants,
  cuisine,
  repassage;

  static CategoryId fromString(String value) {
    return CategoryId.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CategoryId.menage,
    );
  }

  bool get visibleInClientFilter => switch (this) {
    menage || gardeEnfants || cuisine || repassage => true,
    _ => false,
  };

  /// Curated display order of the MVP "home help" tasks for the client filter
  /// and the provider form. This is deliberately NOT the raw enum order (which
  /// is just an insertion artifact) nor alphabetical: it is ordered by recurring
  /// demand and task affinity.
  ///
  /// 1. [menage]        central, most requested task (anchor of the pool)
  /// 2. [repassage]     low-friction recurring chore, frequently bundled with
  ///                    cleaning (same visit), forming a "home upkeep" cluster
  /// 3. [cuisine]       meal help, recurring but slightly heavier commitment
  /// 4. [gardeEnfants]  higher-trust, higher-commitment, less spontaneous, last
  ///
  /// Single source of truth so the client filter and the provider selector never
  /// drift apart. Every entry must satisfy [visibleInClientFilter].
  static const List<CategoryId> clientFilterCategories = <CategoryId>[
    menage,
    repassage,
    cuisine,
    gardeEnfants,
  ];

  String get label => switch (this) {
    menage => 'Ménage',
    plomberie => 'Plomberie',
    jardinage => 'Jardinage',
    electricite => 'Électricité',
    peinture => 'Peinture',
    bricolage => 'Bricolage',
    gardeEnfants => "Garde d'enfants",
    cuisine => 'Cuisine',
    repassage => 'Repassage',
  };
}
