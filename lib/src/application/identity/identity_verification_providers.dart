import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_identity_verification_repository.dart';
import '../../domain/models/identity_verification_record.dart';
import '../../domain/repositories/identity_verification_repository.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_state.dart';

final identityVerificationRepositoryProvider =
    Provider<IdentityVerificationRepository>((ref) {
      return FirestoreIdentityVerificationRepository(
        ref.watch(firestoreProvider),
      );
    });

/// The signed-in provider's most recent identity file (archi 5.6).
///
/// Reads the auth state for the uid rather than taking it as a family key: the
/// status screen only ever shows the current user their own file, and the rule
/// refuses any other read anyway.
final myIdentityVerificationProvider =
    StreamProvider.autoDispose<IdentityVerificationRecord?>((ref) {
      final auth = ref.watch(authNotifierProvider).valueOrNull;
      final uid = auth is AuthAuthenticated ? auth.user.id : null;
      if (uid == null) return const Stream.empty();
      return ref.watch(identityVerificationRepositoryProvider).watchLatest(uid);
    });
