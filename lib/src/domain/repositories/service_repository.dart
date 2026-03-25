import '../models/service.dart';

abstract interface class ServiceRepository {
  Stream<Service?> watchById(String serviceId);
  Stream<List<Service>> watchAllActive();
  Stream<List<Service>> watchForOwner(String ownerId);

  Future<Service> create(Service service);
  Future<void> update(Service service);
}
