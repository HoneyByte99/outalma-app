enum CategoryId {
  menage,
  cuisine,
  plomberie,
  jardinage,
  electricite,
  peinture,
  bricolage,
  gardeEnfants,
  repassage;

  static CategoryId fromString(String value) {
    return CategoryId.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CategoryId.menage,
    );
  }

  String get label => switch (this) {
    menage => 'Ménage',
    cuisine => 'Cuisine',
    plomberie => 'Plomberie',
    jardinage => 'Jardinage',
    electricite => 'Électricité',
    peinture => 'Peinture',
    bricolage => 'Bricolage',
    gardeEnfants => 'Garde d\'enfants',
    repassage => 'Repassage',
  };
}
