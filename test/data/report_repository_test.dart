// Tests for FirestoreReportRepository using FakeFirebaseFirestore.
//
// Covered:
//   - create(report): writes document to reports collection with correct fields
//   - create(report): handles optional 'details' field correctly (omitted when
//     null or empty, present when non-empty)

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_report_repository.dart';
import 'package:outalma_app/src/domain/models/report.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Report _makeReport({
  String id = 'report_1',
  String reporterId = 'user_A',
  String targetType = 'user',
  String targetId = 'user_B',
  String reason = 'spam',
  String? details,
  String status = 'open',
}) {
  return Report(
    id: id,
    reporterId: reporterId,
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    details: details,
    status: status,
    createdAt: DateTime(2024, 6, 1).toUtc(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreReportRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestoreReportRepository(fakeDb);
  });

  // -------------------------------------------------------------------------
  // create
  // -------------------------------------------------------------------------

  group('create', () {
    test('writes a document to the reports collection', () async {
      final report = _makeReport();
      await repo.create(report);

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.length, 1);
    });

    test(
      'persists correct reporterId, targetType, targetId, and reason',
      () async {
        final report = _makeReport(
          reporterId: 'user_X',
          targetType: 'service',
          targetId: 'service_42',
          reason: 'inappropriate',
        );

        await repo.create(report);

        final snap = await fakeDb.collection('reports').get();
        final data = snap.docs.first.data();
        expect(data['reporterId'], 'user_X');
        expect(data['targetType'], 'service');
        expect(data['targetId'], 'service_42');
        expect(data['reason'], 'inappropriate');
      },
    );

    test('persists status field', () async {
      final report = _makeReport(status: 'open');
      await repo.create(report);

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.first.data()['status'], 'open');
    });

    test('includes details when non-null and non-empty', () async {
      final report = _makeReport(details: 'This user sent fake photos.');
      await repo.create(report);

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.first.data()['details'], 'This user sent fake photos.');
    });

    test('omits details field when details is null', () async {
      final report = _makeReport(details: null);
      await repo.create(report);

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.first.data().containsKey('details'), isFalse);
    });

    test('omits details field when details is empty string', () async {
      final report = _makeReport(details: '');
      await repo.create(report);

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.first.data().containsKey('details'), isFalse);
    });

    test('completes without throwing', () async {
      final report = _makeReport();
      await expectLater(repo.create(report), completes);
    });

    test('creates multiple reports independently', () async {
      await repo.create(_makeReport(id: 'r1', targetId: 'user_B'));
      await repo.create(_makeReport(id: 'r2', targetId: 'user_C'));

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.length, 2);
    });

    test('persists createdAt field', () async {
      final report = _makeReport();
      await repo.create(report);

      final snap = await fakeDb.collection('reports').get();
      expect(snap.docs.first.data().containsKey('createdAt'), isTrue);
    });
  });
}
