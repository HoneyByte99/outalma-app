import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../data/repositories/firestore_service_repository.dart';
import '../../domain/models/service.dart';
import '../../domain/repositories/service_repository.dart';
import '../chat/chat_providers.dart';
import '../provider/provider_providers.dart';

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

/// Published services with blocked AND paused providers removed — the base
/// list the discovery page should consume. Blocking is a trust-and-safety
/// policy (coupure totale); pausing is a provider hiding their whole catalogue
/// while they're unavailable. Both are enforced in the application layer here —
/// and server-side at booking time — rather than left to the UI. The remaining
/// view filters (category, search, location, own listings) are applied on top
/// by the discovery page.
final discoverableServicesProvider = Provider<AsyncValue<List<Service>>>((ref) {
  final servicesAsync = ref.watch(serviceListProvider);
  final blocked =
      ref.watch(blockedUserIdsProvider).valueOrNull ?? const <String>{};
  final paused =
      ref.watch(pausedProviderIdsProvider).valueOrNull ?? const <String>{};
  return servicesAsync.whenData(
    (services) => services
        .where(
          (s) =>
              !blocked.contains(s.providerId) && !paused.contains(s.providerId),
        )
        .toList(),
  );
});

/// Single service by id — used for detail page.
final serviceDetailProvider = StreamProvider.autoDispose
    .family<Service?, String>((ref, id) {
      return ref.watch(serviceRepositoryProvider).watchById(id);
    });
