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
