import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/service/service_providers.dart';
import '../../data/repositories/firestore_provider_repository.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/blocked_slot.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/models/service.dart';
import '../../domain/repositories/provider_repository.dart';

/// Stable UID that only changes on real auth transitions (sign-in/sign-out).
/// Never flickers to null during transient re-evaluations.
final _stableUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider).valueOrNull;
  if (auth is AuthAuthenticated) return auth.user.id;
  return null;
});

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return FirestoreProviderRepository(ref.watch(firestoreProvider));
});

/// Current user's provider profile — null if they haven't activated yet.
final currentProviderProfileProvider = StreamProvider<ProviderProfile?>((ref) {
  final uid = ref.watch(_stableUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(providerRepositoryProvider).watchByUid(uid);
});

/// Current provider's own services.
final providerServicesProvider = StreamProvider<List<Service>>((ref) {
  final uid = ref.watch(_stableUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(serviceRepositoryProvider).watchForProvider(uid);
});

/// Incoming booking requests for the current provider (status = requested).
final providerInboxProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(_stableUidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(bookingRepositoryProvider)
      .watchForProvider(uid)
      .map(
        (list) =>
            list.where((b) => b.status == BookingStatus.requested).toList(),
      );
});

/// Active bookings for the current provider (accepted + in_progress).
final providerActiveBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(_stableUidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(bookingRepositoryProvider)
      .watchForProvider(uid)
      .map(
        (list) => list
            .where(
              (b) =>
                  b.status == BookingStatus.accepted ||
                  b.status == BookingStatus.inProgress,
            )
            .toList(),
      );
});

/// Published services for any given provider uid — used on public profile pages.
final publicProviderServicesProvider =
    StreamProvider.family<List<Service>, String>((ref, uid) {
      return ref
          .watch(serviceRepositoryProvider)
          .watchForProvider(uid)
          .map((list) => list.where((s) => s.published).toList());
    });

/// All bookings the current user has received as provider (full history).
final providerBookingHistoryProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(_stableUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).watchForProvider(uid);
});

/// Current provider's blocked slots.
final providerBlockedSlotsProvider = StreamProvider<List<BlockedSlot>>((ref) {
  final uid = ref.watch(_stableUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(providerRepositoryProvider).watchBlockedSlots(uid);
});

/// Blocked slots for any provider — used by clients to check availability.
final blockedSlotsForProviderProvider =
    StreamProvider.family<List<BlockedSlot>, String>((ref, uid) {
      return ref.watch(providerRepositoryProvider).watchBlockedSlots(uid);
    });

/// Bookings for a specific provider on a specific date (accepted/in_progress).
final providerBookingsForDateProvider =
    StreamProvider.family<List<Booking>, ({String providerId, DateTime date})>((
      ref,
      params,
    ) {
      return ref
          .watch(bookingRepositoryProvider)
          .watchForProvider(params.providerId)
          .map(
            (list) => list.where((b) {
              if (b.scheduledAt == null) {
                return false;
              }
              if (b.status != BookingStatus.accepted &&
                  b.status != BookingStatus.inProgress &&
                  b.status != BookingStatus.requested) {
                return false;
              }
              return b.scheduledAt!.year == params.date.year &&
                  b.scheduledAt!.month == params.date.month &&
                  b.scheduledAt!.day == params.date.day;
            }).toList(),
          );
    });
