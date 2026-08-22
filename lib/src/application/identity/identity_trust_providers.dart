import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_identity_trust_repository.dart';
import '../../domain/enums/identity_trust_status.dart';
import '../../domain/repositories/identity_trust_repository.dart';
import '../auth/auth_providers.dart';

final identityTrustRepositoryProvider = Provider<IdentityTrustRepository>((
  ref,
) {
  return FirestoreIdentityTrustRepository(ref.watch(firestoreProvider));
});

/// Public identity state of any provider, by uid.
///
/// One family entry per provider, so several cards showing the same provider
/// share a single listener and a single document read rather than one each.
final identityTrustProvider = StreamProvider.autoDispose
    .family<IdentityTrustStatus?, String>((ref, uid) {
      if (uid.isEmpty) return const Stream.empty();
      return ref.watch(identityTrustRepositoryProvider).watch(uid);
    });
