// Comprehensive coverage for the provider-side Riverpod providers:
//   - identity gating (_stableUidProvider) via authed / unauthenticated paths
//   - profile, services, blocked-slot streams
//   - booking buckets: inbox (requested), active, completed, history
//   - calendar (bookings-for-date) filtering
//   - dashboard KPIs (providerStatsProvider)

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/booking/booking_providers.dart';
import 'package:outalma_app/src/application/provider/provider_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/data/repositories/firestore_provider_repository.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/blocked_slot.dart';
import 'package:outalma_app/src/domain/models/booking.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/repositories/booking_repository.dart';
import 'package:outalma_app/src/domain/repositories/provider_repository.dart';
import 'package:outalma_app/src/domain/repositories/service_repository.dart';

class _MockBookingRepository extends Mock implements BookingRepository {}

class _MockServiceRepository extends Mock implements ServiceRepository {}

class _MockProviderRepository extends Mock implements ProviderRepository {}

class _AuthedNotifier extends AuthNotifier {
  _AuthedNotifier(this._user);
  final AppUser _user;
  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

const pid = 'provider_1';

AppUser _provider() => AppUser(
  id: pid,
  displayName: 'Pro',
  email: 'pro@test.com',
  country: 'FR',
  activeMode: ActiveMode.provider,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

Booking _b(
  String id,
  BookingStatus status, {
  DateTime? createdAt,
  DateTime? scheduledAt,
}) => Booking(
  id: id,
  customerId: 'client_1',
  providerId: pid,
  serviceId: 'service_1',
  status: status,
  requestMessage: '',
  createdAt: createdAt ?? DateTime(2024, 1, 15).toUtc(),
  scheduledAt: scheduledAt,
);

Service _service(String id, {required bool published}) => Service(
  id: id,
  providerId: pid,
  categoryId: CategoryId.menage,
  title: 'S$id',
  photos: const [],
  priceType: PriceType.fixed,
  price: 100,
  published: published,
  createdAt: DateTime(2024, 1, 1).toUtc(),
  updatedAt: DateTime(2024, 1, 1).toUtc(),
);

ProviderProfile _profile() => ProviderProfile(
  uid: pid,
  active: true,
  suspended: false,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

void main() {
  late _MockBookingRepository bookingRepo;
  late _MockServiceRepository serviceRepo;
  late _MockProviderRepository providerRepo;

  setUp(() {
    bookingRepo = _MockBookingRepository();
    serviceRepo = _MockServiceRepository();
    providerRepo = _MockProviderRepository();
  });

  ProviderContainer authed({List<Booking> bookings = const []}) {
    when(
      () => bookingRepo.watchForProvider(pid),
    ).thenAnswer((_) => Stream.value(bookings));
    return ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
        serviceRepositoryProvider.overrideWithValue(serviceRepo),
        providerRepositoryProvider.overrideWithValue(providerRepo),
        authNotifierProvider.overrideWith(() => _AuthedNotifier(_provider())),
      ],
    );
  }

  group('booking buckets (authenticated)', () {
    final mixed = [
      _b('req', BookingStatus.requested),
      _b('acc', BookingStatus.accepted),
      _b('prog', BookingStatus.inProgress),
      _b('done', BookingStatus.done),
      _b('rej', BookingStatus.rejected),
      _b('can', BookingStatus.cancelled),
    ];

    test('inbox keeps only requested', () async {
      final c = authed(bookings: mixed);
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      final list = await c.read(providerInboxProvider.future);
      expect(list.map((b) => b.id), ['req']);
    });

    test('active keeps accepted + in_progress', () async {
      final c = authed(bookings: mixed);
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      final list = await c.read(providerActiveBookingsProvider.future);
      expect(list.map((b) => b.id).toSet(), {'acc', 'prog'});
    });

    test('completed keeps done + rejected + cancelled', () async {
      final c = authed(bookings: mixed);
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      final list = await c.read(providerCompletedBookingsProvider.future);
      expect(list.map((b) => b.id).toSet(), {'done', 'rej', 'can'});
    });

    test('history returns everything', () async {
      final c = authed(bookings: mixed);
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      final list = await c.read(providerBookingHistoryProvider.future);
      expect(list, hasLength(6));
    });
  });

  group('profile + services', () {
    test('currentProviderProfileProvider streams the profile', () async {
      when(
        () => providerRepo.watchByUid(pid),
      ).thenAnswer((_) => Stream.value(_profile()));
      final c = authed();
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      final p = await c.read(currentProviderProfileProvider.future);
      expect(p?.uid, pid);
    });

    test('providerProfileByIdProvider streams a profile by uid', () async {
      when(
        () => providerRepo.watchByUid('x'),
      ).thenAnswer((_) => Stream.value(_profile()));
      final c = authed();
      addTearDown(c.dispose);
      expect((await c.read(providerProfileByIdProvider('x').future))?.uid, pid);
    });

    test('providerServicesProvider streams own services', () async {
      when(
        () => serviceRepo.watchForProvider(pid),
      ).thenAnswer((_) => Stream.value([_service('1', published: true)]));
      final c = authed();
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      final list = await c.read(providerServicesProvider.future);
      expect(list, hasLength(1));
    });

    test('publicProviderServicesProvider keeps only published', () async {
      when(() => serviceRepo.watchForProvider(pid)).thenAnswer(
        (_) => Stream.value([
          _service('1', published: true),
          _service('2', published: false),
        ]),
      );
      final c = authed();
      addTearDown(c.dispose);
      final list = await c.read(publicProviderServicesProvider(pid).future);
      expect(list.map((s) => s.id), ['1']);
    });
  });

  group('blocked slots', () {
    final slots = [BlockedSlot(id: 's1', date: DateTime(2026, 3, 1).toUtc())];

    test('providerBlockedSlotsProvider (current user)', () async {
      when(
        () => providerRepo.watchBlockedSlots(pid),
      ).thenAnswer((_) => Stream.value(slots));
      final c = authed();
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      expect(await c.read(providerBlockedSlotsProvider.future), hasLength(1));
    });

    test('blockedSlotsForProviderProvider (any uid)', () async {
      when(
        () => providerRepo.watchBlockedSlots('other'),
      ).thenAnswer((_) => Stream.value(slots));
      final c = authed();
      addTearDown(c.dispose);
      expect(
        await c.read(blockedSlotsForProviderProvider('other').future),
        hasLength(1),
      );
    });
  });

  group('providerBookingsForDateProvider', () {
    test(
      'keeps only scheduled bookings on the target day with valid status',
      () async {
        final day = DateTime(2026, 5, 10);
        when(() => bookingRepo.watchForProvider('px')).thenAnswer(
          (_) => Stream.value([
            _b('noSched', BookingStatus.accepted),
            _b(
              'wrongStatus',
              BookingStatus.done,
              scheduledAt: DateTime(2026, 5, 10, 9),
            ),
            _b(
              'otherDay',
              BookingStatus.accepted,
              scheduledAt: DateTime(2026, 5, 11, 9),
            ),
            _b(
              'match',
              BookingStatus.accepted,
              scheduledAt: DateTime(2026, 5, 10, 14),
            ),
            _b(
              'matchReq',
              BookingStatus.requested,
              scheduledAt: DateTime(2026, 5, 10, 16),
            ),
          ]),
        );
        final c = authed();
        addTearDown(c.dispose);
        final list = await c.read(
          providerBookingsForDateProvider((providerId: 'px', date: day)).future,
        );
        expect(list.map((b) => b.id).toSet(), {'match', 'matchReq'});
      },
    );
  });

  group('providerStatsProvider', () {
    test('computes month count, acceptance rate and upcoming', () async {
      final now = DateTime.now();
      final c = authed(
        bookings: [
          // counts toward this month + accepted
          _b('a', BookingStatus.accepted, createdAt: now),
          // old → not this month, rejected
          _b('r', BookingStatus.rejected, createdAt: DateTime(2000)),
          // upcoming within 7 days, accepted
          _b(
            'u',
            BookingStatus.inProgress,
            createdAt: now,
            scheduledAt: now.add(const Duration(days: 2)),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      await c.read(providerBookingHistoryProvider.future);
      final stats = c.read(providerStatsProvider);
      expect(stats.bookingsThisMonth, 2); // 'a' and 'u'
      // accepted=2 (a, u), rejected=1 → 2/3
      expect(stats.acceptanceRate, closeTo(2 / 3, 0.0001));
      expect(stats.upcomingThisWeek, 1);
    });

    test('acceptanceRate is null with no decisions', () async {
      final c = authed(bookings: const []);
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      await c.read(providerBookingHistoryProvider.future);
      final stats = c.read(providerStatsProvider);
      expect(stats.acceptanceRate, isNull);
      expect(stats.bookingsThisMonth, 0);
      expect(stats.upcomingThisWeek, 0);
    });
  });

  group('providerRepositoryProvider', () {
    test(
      'builds a FirestoreProviderRepository from the firestore instance',
      () {
        final c = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
        );
        addTearDown(c.dispose);
        expect(
          c.read(providerRepositoryProvider),
          isA<FirestoreProviderRepository>(),
        );
      },
    );
  });
}
