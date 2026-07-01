import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_public_profile_repository.dart';
import '../../domain/models/public_profile.dart';
import '../../domain/repositories/public_profile_repository.dart';
import '../auth/auth_providers.dart';

/// Repository for the world-readable [PublicProfile] projection.
final publicProfileRepositoryProvider = Provider<PublicProfileRepository>(
  (ref) => FirestorePublicProfileRepository(ref.watch(firestoreProvider)),
);

/// Streams a single [PublicProfile] by uid from the world-readable projection.
///
/// This is the guest-safe way to resolve a provider's or reviewer's display
/// name / avatar / country: it never touches the PII-bearing `users` doc, so it
/// works for unauthenticated visitors. Prefer this over `userByIdProvider` for
/// any display-only need on public surfaces (cards, public profiles, reviews).
final publicProfileByIdProvider = StreamProvider.autoDispose
    .family<PublicProfile?, String>((ref, uid) {
      return ref.watch(publicProfileRepositoryProvider).watchById(uid);
    });
