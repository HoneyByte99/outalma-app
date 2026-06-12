import '../models/service.dart';

abstract interface class ServiceRepository {
  Stream<Service?> watchById(String serviceId);

  /// Real-time stream of the first [limit] published services (default 30).
  /// Increase [limit] to load more — Firestore will push updates as needed.
  Stream<List<Service>> watchAllPublished({int limit = 30});

  Stream<List<Service>> watchForProvider(String providerId);

  Future<Service> create(Service service);
  Future<void> update(Service service);

  /// Permanently deletes a service (owner-only, enforced by Firestore rules).
  Future<void> delete(String serviceId);
}
