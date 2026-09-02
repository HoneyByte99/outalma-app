import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_public_profile_repository.dart';
import '../../domain/models/public_profile.dart';
import '../../domain/repositories/public_profile_repository.dart';
import '../auth/auth_providers.dart';

/// Repository for the world-readable [PublicProfile] projection.
final publicProfileRepositoryProvider = Provider<PublicProfileRepository>(
  (ref) => FirestorePublicProfileRepository(ref.watch(firestoreProvider)),
);

/// Streams one [PublicProfile] by uid.
///
/// This is the guest-safe way to resolve a display name, an avatar or the
/// phone-verified flag. Use it on EVERY surface a visitor without an account can
/// reach (home cards, service detail, public provider profile, reviews);
/// `userByIdProvider` reads `users/{uid}`, which is gated on `signedIn()` and
/// therefore fails for a guest. `userByIdProvider` stays correct behind the
/// login wall (chat, bookings, own profile), where the extra fields are needed.
///
/// autoDispose: a reviews list instantiates one provider per distinct uid, which
/// would otherwise accumulate Firestore listeners for the app's lifetime.
final publicProfileByIdProvider = StreamProvider.autoDispose
    .family<PublicProfile?, String>((ref, uid) {
      return ref.watch(publicProfileRepositoryProvider).watchById(uid);
    });
