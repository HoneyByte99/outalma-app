import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../data/repositories/firestore_booking_repository.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import 'create_booking_use_case.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return FirestoreBookingRepository(ref.watch(firestoreProvider));
});

/// Watches all bookings for the currently authenticated customer.
/// Returns an empty stream when unauthenticated.
final customerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  return ref
      .watch(bookingRepositoryProvider)
      .watchForCustomer(authState.user.id);
});

/// Single booking by id — used for detail page.
final bookingDetailProvider = StreamProvider.family<Booking?, String>((
  ref,
  bookingId,
) {
  return ref.watch(bookingRepositoryProvider).watchById(bookingId);
});

/// Count of client bookings that require attention (accepted or in_progress).
final clientActiveBookingsCountProvider = Provider<int>((ref) {
  final list = ref.watch(customerBookingsProvider).valueOrNull ?? [];
  return list
      .where(
        (b) =>
            b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress,
      )
      .length;
});

/// Injectable use case — features layer must consume this, never instantiate
/// CreateBookingUseCase or FirebaseFunctions directly.
final createBookingUseCaseProvider = Provider<CreateBookingUseCase>((ref) {
  return CreateBookingUseCase(FirebaseFunctions.instance);
});
