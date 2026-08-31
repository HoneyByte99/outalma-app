// Coverage for the review Riverpod providers:
//   - reviewRepositoryProvider construction
//   - reviewsForUserProvider / reviewsForBookingProvider streams
//   - ratingSummaryProvider aggregate (average + count)
//   - hasReviewedProvider (authed true/false + unauthenticated)
//   - createReviewUseCaseProvider wiring
//
// CreateReviewUseCase.call() behaviour is covered separately in
// create_review_use_case_test.dart / review_pairing_test.dart.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/repositories/provider_rating_repository.dart';
import 'package:outalma_app/src/domain/models/provider_rating.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/data/repositories/firestore_review_repository.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/domain/repositories/review_repository.dart';

class _MockReviewRepository extends Mock implements ReviewRepository {}

class _AuthedNotifier extends AuthNotifier {
  _AuthedNotifier(this._user);
  final AppUser _user;
  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

class _UnauthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

AppUser _user(String id) => AppUser(
  id: id,
  displayName: 'U',
  email: '$id@test.com',
  country: 'FR',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

Review _r(String id, {String reviewerId = 'someone', int rating = 5}) => Review(
  id: id,
  bookingId: 'b1',
  reviewerId: reviewerId,
  revieweeId: 'target',
  reviewerRole: ReviewerRole.client,
  rating: rating,
  createdAt: DateTime(2024, 1, 1).toUtc(),
);

void main() {
  late _MockReviewRepository repo;
  setUp(() => repo = _MockReviewRepository());

  ProviderContainer makeContainer({AuthNotifier Function()? auth}) =>
      ProviderContainer(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repo),
          if (auth != null) authNotifierProvider.overrideWith(auth),
        ],
      );

  test('reviewRepositoryProvider builds a FirestoreReviewRepository', () {
    final c = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(FakeFirebaseFirestore())],
    );
    addTearDown(c.dispose);
    expect(c.read(reviewRepositoryProvider), isA<FirestoreReviewRepository>());
  });

  test('reviewsForUserProvider streams reviews received by a user', () async {
    when(
      () => repo.watchForUser('target'),
    ).thenAnswer((_) => Stream.value([_r('a'), _r('b')]));
    final c = makeContainer();
    addTearDown(c.dispose);
    final list = await c.read(reviewsForUserProvider('target').future);
    expect(list, hasLength(2));
  });

  test('reviewsForBookingProvider streams reviews for a booking', () async {
    when(
      () => repo.watchForBooking('b1'),
    ).thenAnswer((_) => Stream.value([_r('a')]));
    final c = makeContainer();
    addTearDown(c.dispose);
    final list = await c.read(reviewsForBookingProvider('b1').future);
    expect(list, hasLength(1));
  });

  group('providerRatingProvider', () {
    test('maps the server aggregate through the shared display rule', () async {
      final c = ProviderContainer(
        overrides: [
          providerRatingRepositoryProvider.overrideWithValue(
            _StubRatingRepo(const ProviderRating(sum: 12, count: 3)),
          ),
        ],
      );
      addTearDown(c.dispose);
      final d = await c.read(providerRatingProvider('prov_1').future);
      expect(d.isNew, isFalse);
      expect(d.average, closeTo(4.0, 0.0001));
      expect(d.count, 3);
    });

    test('applies the same floor as everywhere else', () async {
      final c = ProviderContainer(
        overrides: [
          providerRatingRepositoryProvider.overrideWithValue(
            _StubRatingRepo(const ProviderRating(sum: 2, count: 1)),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(
        (await c.read(providerRatingProvider('prov_1').future)).isNew,
        isTrue,
      );
    });
  });

  group('clientReputationProvider', () {
    test('averages the bounded window of recent reviews', () async {
      when(
        () => repo.watchRecentForUser('target', limit: kClientReputationWindow),
      ).thenAnswer(
        (_) => Stream.value([
          _r('a', rating: 5),
          _r('b', rating: 4),
          _r('c', rating: 3),
        ]),
      );
      final c = makeContainer();
      addTearDown(c.dispose);
      final stats = await c.read(clientReputationProvider('target').future);
      expect(stats.isNew, isFalse);
      expect(stats.count, 3);
      expect(stats.average, closeTo(4.0, 0.0001));
    });

    test('stays "Nouveau" below the review floor', () async {
      when(
        () => repo.watchRecentForUser('target', limit: kClientReputationWindow),
      ).thenAnswer((_) => Stream.value([_r('a', rating: 2)]));
      final c = makeContainer();
      addTearDown(c.dispose);
      final stats = await c.read(clientReputationProvider('target').future);
      expect(stats.isNew, isTrue, reason: 'one review is not a verdict');
      expect(stats.average, isNull);
    });

    test('reads the BOUNDED query, never the unbounded one', () async {
      // The whole point of the separate method: the card path must not reopen
      // the unbounded stream this increment removed.
      when(
        () => repo.watchRecentForUser('target', limit: kClientReputationWindow),
      ).thenAnswer((_) => Stream.value(<Review>[]));
      final c = makeContainer();
      addTearDown(c.dispose);
      await c.read(clientReputationProvider('target').future);
      verifyNever(() => repo.watchForUser('target'));
    });
  });

  group('hasReviewedProvider', () {
    test('true when the current user already reviewed', () async {
      when(
        () => repo.watchForBooking('b1'),
      ).thenAnswer((_) => Stream.value([_r('a', reviewerId: 'me')]));
      final c = makeContainer(auth: () => _AuthedNotifier(_user('me')));
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      expect(await c.read(hasReviewedProvider('b1').future), isTrue);
    });

    test('false when only the counterparty reviewed', () async {
      when(
        () => repo.watchForBooking('b1'),
      ).thenAnswer((_) => Stream.value([_r('a', reviewerId: 'someone_else')]));
      final c = makeContainer(auth: () => _AuthedNotifier(_user('me')));
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      expect(await c.read(hasReviewedProvider('b1').future), isFalse);
    });

    test('false when unauthenticated', () async {
      final c = makeContainer(auth: () => _UnauthNotifier());
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      expect(await c.read(hasReviewedProvider('b1').future), isFalse);
    });
  });

  test('createReviewUseCaseProvider exposes a CreateReviewUseCase', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    expect(c.read(createReviewUseCaseProvider), isA<CreateReviewUseCase>());
  });
}

class _StubRatingRepo implements ProviderRatingRepository {
  _StubRatingRepo(this._value);
  final ProviderRating _value;

  @override
  Stream<ProviderRating> watch(String uid) => Stream.value(_value);
}
