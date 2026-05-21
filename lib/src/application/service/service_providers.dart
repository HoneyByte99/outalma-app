import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../data/repositories/firestore_service_repository.dart';
import '../../domain/models/service.dart';
import '../../domain/repositories/service_repository.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return FirestoreServiceRepository(ref.watch(firestoreProvider));
});

/// Current "page size" for the discovery list — incremented by the UI to
/// load more services. Resets to 30 on each app start.
final serviceListPageSizeProvider = StateProvider<int>((_) => 30);

/// All published services — used as the canonical source for discovery.
/// Re-subscribes when [serviceListPageSizeProvider] grows; Firestore keeps
/// the stream live so newly published services appear in real time.
final serviceListProvider = StreamProvider<List<Service>>((ref) {
  final limit = ref.watch(serviceListPageSizeProvider);
  return ref.watch(serviceRepositoryProvider).watchAllPublished(limit: limit);
});

/// Single service by id — used for detail page.
final serviceDetailProvider = StreamProvider.family<Service?, String>((
  ref,
  id,
) {
  return ref.watch(serviceRepositoryProvider).watchById(id);
});
