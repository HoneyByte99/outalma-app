import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../data/repositories/firestore_service_repository.dart';
import '../../domain/models/service.dart';
import '../../domain/repositories/service_repository.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return FirestoreServiceRepository(ref.watch(firestoreProvider));
});

/// All published services — used as the canonical source for discovery.
final serviceListProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(serviceRepositoryProvider).watchAllPublished();
});

/// Single service by id — used for detail page.
final serviceDetailProvider = StreamProvider.family<Service?, String>((
  ref,
  id,
) {
  return ref.watch(serviceRepositoryProvider).watchById(id);
});
