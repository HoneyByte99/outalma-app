// Tests booking-related Riverpod providers using ProviderContainer + mocktail.
//
// Covered:
//   - customerBookingsProvider: streams bookings for the authenticated user
//   - bookingDetailProvider: single booking lookup by id
//   - clientActiveBookingsCountProvider: counts accepted + inProgress only

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/booking/booking_providers.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/booking.dart';
import 'package:outalma_app/src/domain/repositories/booking_repository.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockBookingRepository extends Mock implements BookingRepository {}

class _AuthenticatedNotifier extends AuthNotifier {
  _AuthenticatedNotifier(this._user);
  final AppUser _user;

  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppUser _makeUser({String id = 'user_1'}) => AppUser(
  id: id,
  displayName: 'Alice',
  email: 'alice@test.com',
  country: 'FR',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

Booking _makeBooking(String id, BookingStatus status) => Booking(
  id: id,
  customerId: 'user_1',
  providerId: 'provider_1',
  serviceId: 'service_1',
  status: status,
  requestMessage: 'Test message',
  createdAt: DateTime(2024, 1, 15).toUtc(),
);

ProviderContainer _makeContainer(
  _MockBookingRepository mockRepo, {
  AppUser? user,
}) {
  return ProviderContainer(
    overrides: [
      bookingRepositoryProvider.overrideWithValue(mockRepo),
      authNotifierProvider.overrideWith(
        () => _AuthenticatedNotifier(user ?? _makeUser()),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockBookingRepository mockRepo;

  setUp(() {
    mockRepo = _MockBookingRepository();
    registerFallbackValue(_makeBooking('fallback', BookingStatus.requested));
  });

  // -------------------------------------------------------------------------
  // customerBookingsProvider
  // -------------------------------------------------------------------------

  group('customerBookingsProvider', () {
    test('returns empty list when stream emits empty', () async {
      when(
        () => mockRepo.watchForCustomer(any()),
      ).thenAnswer((_) => Stream.value([]));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      final result = await container.read(customerBookingsProvider.future);
      expect(result, isEmpty);
    });

    test('returns bookings from the repository stream', () async {
      final bookings = [
        _makeBooking('b1', BookingStatus.requested),
        _makeBooking('b2', BookingStatus.accepted),
      ];
      when(
        () => mockRepo.watchForCustomer('user_1'),
      ).thenAnswer((_) => Stream.value(bookings));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      final result = await container.read(customerBookingsProvider.future);

      expect(result.length, 2);
      expect(result.first.id, 'b1');
      expect(result.last.id, 'b2');
    });

    test('queries repository with the authenticated user id', () async {
      when(
        () => mockRepo.watchForCustomer('user_1'),
      ).thenAnswer((_) => Stream.value([]));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(customerBookingsProvider.future);

      verify(() => mockRepo.watchForCustomer('user_1')).called(1);
    });

    test('reflects stream updates over time', () async {
      final controller = StreamController<List<Booking>>();
      when(
        () => mockRepo.watchForCustomer(any()),
      ).thenAnswer((_) => controller.stream);
      final container = _makeContainer(mockRepo);
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      await container.read(authNotifierProvider.future);
      // Initialize the StreamProvider so it subscribes to the stream
      container.read(customerBookingsProvider);

      // Emit first batch
      controller.add([_makeBooking('b1', BookingStatus.requested)]);
      await pumpEventQueue();
      var result = container.read(customerBookingsProvider).valueOrNull ?? [];
      expect(result.length, 1);

      // Emit second batch (booking accepted, new booking added)
      controller.add([
        _makeBooking('b1', BookingStatus.accepted),
        _makeBooking('b2', BookingStatus.requested),
      ]);
      await pumpEventQueue();
      result = container.read(customerBookingsProvider).valueOrNull ?? [];
      expect(result.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // clientActiveBookingsCountProvider
  // -------------------------------------------------------------------------

  group('clientActiveBookingsCountProvider', () {
    test('counts accepted + inProgress bookings only', () async {
      final bookings = [
        _makeBooking('b1', BookingStatus.requested), // not active
        _makeBooking('b2', BookingStatus.accepted), // active
        _makeBooking('b3', BookingStatus.inProgress), // active
        _makeBooking('b4', BookingStatus.done), // not active
        _makeBooking('b5', BookingStatus.cancelled), // not active
        _makeBooking('b6', BookingStatus.rejected), // not active
      ];
      when(
        () => mockRepo.watchForCustomer('user_1'),
      ).thenAnswer((_) => Stream.value(bookings));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(customerBookingsProvider.future);

      final count = container.read(clientActiveBookingsCountProvider);
      expect(
        count,
        2,
        reason: 'Only b2 (accepted) and b3 (inProgress) are active',
      );
    });

    test('returns 0 when no bookings', () async {
      when(
        () => mockRepo.watchForCustomer('user_1'),
      ).thenAnswer((_) => Stream.value([]));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(customerBookingsProvider.future);

      expect(container.read(clientActiveBookingsCountProvider), 0);
    });

    test('returns 0 when all bookings are terminal', () async {
      final bookings = [
        _makeBooking('b1', BookingStatus.done),
        _makeBooking('b2', BookingStatus.cancelled),
        _makeBooking('b3', BookingStatus.rejected),
      ];
      when(
        () => mockRepo.watchForCustomer('user_1'),
      ).thenAnswer((_) => Stream.value(bookings));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container.read(customerBookingsProvider.future);

      expect(container.read(clientActiveBookingsCountProvider), 0);
    });
  });

  // -------------------------------------------------------------------------
  // bookingDetailProvider
  // -------------------------------------------------------------------------

  group('bookingDetailProvider', () {
    test('returns the booking when found', () async {
      final booking = _makeBooking('b1', BookingStatus.accepted);
      when(
        () => mockRepo.watchById('b1'),
      ).thenAnswer((_) => Stream.value(booking));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final result = await container.read(bookingDetailProvider('b1').future);
      expect(result?.id, 'b1');
      expect(result?.status, BookingStatus.accepted);
    });

    test('returns null when booking is not found', () async {
      when(
        () => mockRepo.watchById('unknown'),
      ).thenAnswer((_) => Stream.value(null));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final result = await container.read(
        bookingDetailProvider('unknown').future,
      );
      expect(result, isNull);
    });

    test('reflects status changes from stream', () async {
      final controller = StreamController<Booking?>();
      when(() => mockRepo.watchById('b1')).thenAnswer((_) => controller.stream);
      final container = _makeContainer(mockRepo);
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      // Initialize provider (subscribe to stream)
      container.read(bookingDetailProvider('b1'));

      // Emit requested
      controller.add(_makeBooking('b1', BookingStatus.requested));
      await pumpEventQueue();
      var result = container.read(bookingDetailProvider('b1')).valueOrNull;
      expect(result?.status, BookingStatus.requested);

      // Emit accepted (provider accepted)
      controller.add(_makeBooking('b1', BookingStatus.accepted));
      await pumpEventQueue();
      result = container.read(bookingDetailProvider('b1')).valueOrNull;
      expect(result?.status, BookingStatus.accepted);
    });
  });
}
