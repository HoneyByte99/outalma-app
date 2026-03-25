enum ServiceStatus {
  draft,
  active,
  inactive;

  static ServiceStatus fromString(String value) {
    return ServiceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ServiceStatus.draft,
    );
  }
}
