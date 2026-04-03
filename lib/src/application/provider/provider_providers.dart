import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/service/service_providers.dart';
import '../../data/repositories/firestore_provider_repository.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/models/service.dart';
import '../../domain/repositories/provider_repository.dart';

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return FirestoreProviderRepository(ref.watch(firestoreProvider));
});

/// Current user's provider profile — null if they haven't activated yet.
final currentProviderProfileProvider = StreamProvider<ProviderProfile?>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  return ref
      .watch(providerRepositoryProvider)
      .watchByUid(authState.user.id);
});

/// Current provider's own services.
final providerServicesProvider = StreamProvider<List<Service>>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  return ref
      .watch(serviceRepositoryProvider)
      .watchForProvider(authState.user.id);
});

/// Incoming booking requests for the current provider (status = requested).
final providerInboxProvider = StreamProvider<List<Booking>>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  return ref
      .watch(bookingRepositoryProvider)
      .watchForProvider(authState.user.id)
      .map((list) => list
          .where((b) => b.status == BookingStatus.requested)
          .toList());
});

/// Active bookings for the current provider (accepted + in_progress).
final providerActiveBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  return ref
      .watch(bookingRepositoryProvider)
      .watchForProvider(authState.user.id)
      .map((list) => list
          .where((b) =>
              b.status == BookingStatus.accepted ||
              b.status == BookingStatus.inProgress)
          .toList());
});

/// All bookings the current user has received as provider (full history).
final providerBookingHistoryProvider = StreamProvider<List<Booking>>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return const Stream.empty();
  return ref
      .watch(bookingRepositoryProvider)
      .watchForProvider(authState.user.id);
});
