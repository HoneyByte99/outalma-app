import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../data/repositories/firestore_phone_share_repository.dart';
import '../../domain/models/phone_share.dart';
import '../../domain/repositories/phone_share_repository.dart';

final phoneShareRepositoryProvider = Provider<PhoneShareRepository>((ref) {
  return FirestorePhoneShareRepository(ref.watch(firestoreProvider));
});

/// All phone shares for a booking.
final phoneSharesProvider = StreamProvider.family<List<PhoneShare>, String>((
  ref,
  bookingId,
) {
  return ref.watch(phoneShareRepositoryProvider).watchForBooking(bookingId);
});

/// Whether the current user has already shared their phone for this booking.
final hasSharedPhoneProvider = StreamProvider.family<bool, String>((
  ref,
  bookingId,
) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return Stream.value(false);
  final uid = authState.user.id;
  return ref
      .watch(phoneShareRepositoryProvider)
      .watchForBooking(bookingId)
      .map((shares) => shares.any((s) => s.uid == uid));
});
