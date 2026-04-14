import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/service.dart';
import '../../domain/repositories/service_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreServiceRepository implements ServiceRepository {
  const FirestoreServiceRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Service?> watchById(String serviceId) {
    return FirestoreCollections.services(_db)
        .doc(serviceId)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Stream<List<Service>> watchAllPublished() {
    return FirestoreCollections.services(_db)
        .where('published', isEqualTo: true)
        .limit(100)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Stream<List<Service>> watchForProvider(String providerId) {
    return FirestoreCollections.services(_db)
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Future<Service> create(Service service) async {
    final col = FirestoreCollections.services(_db);
    if (service.id.isEmpty) {
      final ref = col.doc();
      await ref.set(service);
      final snap = await ref.get();
      return snap.data()!;
    } else {
      await col.doc(service.id).set(service);
      return service;
    }
  }

  @override
  Future<void> update(Service service) async {
    await FirestoreCollections.services(_db)
        .doc(service.id)
        .set(service, SetOptions(merge: true));
  }
}
