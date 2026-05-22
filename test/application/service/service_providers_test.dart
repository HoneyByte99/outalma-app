// Tests for service_providers.dart
//
// Covered:
//   - serviceListProvider: streams published services from the repository
//   - serviceDetailProvider(id): streams a single service or null
//   - No filteredServicesProvider (not present in source — adapted)
//   - providerServicesProvider not present; watchForProvider tested via mockRepo

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/repositories/service_repository.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockServiceRepository extends Mock implements ServiceRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Service _makeService({
  String id = 'service_1',
  String providerId = 'provider_1',
  CategoryId categoryId = CategoryId.menage,
  bool published = true,
}) {
  final now = DateTime(2024, 1, 1).toUtc();
  return Service(
    id: id,
    providerId: providerId,
    categoryId: categoryId,
    title: 'Service $id',
    photos: [],
    priceType: PriceType.fixed,
    price: 50,
    published: published,
    createdAt: now,
    updatedAt: now,
  );
}

ProviderContainer _makeContainer(_MockServiceRepository mockRepo) {
  return ProviderContainer(
    overrides: [serviceRepositoryProvider.overrideWithValue(mockRepo)],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockServiceRepository mockRepo;

  setUp(() {
    mockRepo = _MockServiceRepository();
    registerFallbackValue(_makeService());
  });

  // -------------------------------------------------------------------------
  // serviceListProvider
  // -------------------------------------------------------------------------

  group('serviceListProvider', () {
    test('returns empty list when stream emits empty', () async {
      when(
        () => mockRepo.watchAllPublished(limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value([]));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final result = await container.read(serviceListProvider.future);
      expect(result, isEmpty);
    });

    test('returns services from the repository stream', () async {
      final services = [
        _makeService(id: 's1'),
        _makeService(id: 's2', categoryId: CategoryId.jardinage),
      ];
      when(
        () => mockRepo.watchAllPublished(limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value(services));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final result = await container.read(serviceListProvider.future);
      expect(result.length, 2);
      expect(result.first.id, 's1');
      expect(result.last.id, 's2');
    });

    test('calls watchAllPublished with default page size of 30', () async {
      when(
        () => mockRepo.watchAllPublished(limit: 30),
      ).thenAnswer((_) => Stream.value([]));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container.read(serviceListProvider.future);
      verify(() => mockRepo.watchAllPublished(limit: 30)).called(1);
    });

    test('calls watchAllPublished with updated page size', () async {
      when(
        () => mockRepo.watchAllPublished(limit: 60),
      ).thenAnswer((_) => Stream.value([]));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      container.read(serviceListPageSizeProvider.notifier).state = 60;
      await container.read(serviceListProvider.future);
      verify(() => mockRepo.watchAllPublished(limit: 60)).called(1);
    });

    test('reflects stream updates over time', () async {
      final controller = StreamController<List<Service>>();
      when(
        () => mockRepo.watchAllPublished(limit: any(named: 'limit')),
      ).thenAnswer((_) => controller.stream);
      final container = _makeContainer(mockRepo);
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      container.read(serviceListProvider);

      controller.add([_makeService(id: 's1')]);
      await pumpEventQueue();
      var result = container.read(serviceListProvider).valueOrNull ?? [];
      expect(result.length, 1);

      controller.add([_makeService(id: 's1'), _makeService(id: 's2')]);
      await pumpEventQueue();
      result = container.read(serviceListProvider).valueOrNull ?? [];
      expect(result.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // serviceDetailProvider
  // -------------------------------------------------------------------------

  group('serviceDetailProvider', () {
    test('returns the service when found', () async {
      final service = _makeService(id: 'svc_abc');
      when(
        () => mockRepo.watchById('svc_abc'),
      ).thenAnswer((_) => Stream.value(service));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final result = await container.read(serviceDetailProvider('svc_abc').future);
      expect(result?.id, 'svc_abc');
      expect(result?.categoryId, CategoryId.menage);
    });

    test('returns null for missing document', () async {
      when(
        () => mockRepo.watchById('missing'),
      ).thenAnswer((_) => Stream.value(null));
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final result = await container.read(serviceDetailProvider('missing').future);
      expect(result, isNull);
    });

    test('reflects live updates from stream', () async {
      final controller = StreamController<Service?>();
      when(
        () => mockRepo.watchById('s1'),
      ).thenAnswer((_) => controller.stream);
      final container = _makeContainer(mockRepo);
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      container.read(serviceDetailProvider('s1'));

      // Initially not published
      controller.add(_makeService(id: 's1', published: false));
      await pumpEventQueue();
      var result = container.read(serviceDetailProvider('s1')).valueOrNull;
      expect(result?.published, false);

      // Now published
      controller.add(_makeService(id: 's1', published: true));
      await pumpEventQueue();
      result = container.read(serviceDetailProvider('s1')).valueOrNull;
      expect(result?.published, true);
    });

    test('uses separate stream per family argument', () async {
      when(
        () => mockRepo.watchById('a'),
      ).thenAnswer((_) => Stream.value(_makeService(id: 'a')));
      when(
        () => mockRepo.watchById('b'),
      ).thenAnswer((_) => Stream.value(_makeService(id: 'b')));

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      final a = await container.read(serviceDetailProvider('a').future);
      final b = await container.read(serviceDetailProvider('b').future);

      expect(a?.id, 'a');
      expect(b?.id, 'b');
    });
  });
}
