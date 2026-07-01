// Verifies that Report objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases:
//   - All fields roundtrip
//   - targetType string values: "user", "service", "message"
//   - reason field preserved
//   - details null / non-null
//   - status values: "open", "resolved", "dismissed"
//   - Missing fields → safe defaults, no crash

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/models/report.dart';

Report _makeReport({
  String id = 'report_1',
  String reporterId = 'user_reporter',
  String targetType = 'user',
  String targetId = 'user_target',
  String reason = 'Comportement inapproprié',
  String? details,
  String status = 'open',
  DateTime? createdAt,
}) {
  return Report(
    id: id,
    reporterId: reporterId,
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    details: details,
    status: status,
    createdAt: createdAt ?? DateTime(2024, 4, 20, 14, 0).toUtc(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Report serialization - all fields', () {
    test('roundtrip preserves all fields', () async {
      final report = _makeReport(
        details: 'Il a été grossier lors de la prestation.',
      );
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;

      expect(result.id, report.id);
      expect(result.reporterId, 'user_reporter');
      expect(result.targetType, 'user');
      expect(result.targetId, 'user_target');
      expect(result.reason, 'Comportement inapproprié');
      expect(result.details, 'Il a été grossier lors de la prestation.');
      expect(result.status, 'open');
    });
  });

  group('Report serialization - targetType values', () {
    test('targetType "user" roundtrips correctly', () async {
      final report = _makeReport(id: 'report_user', targetType: 'user');
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.targetType, 'user');
    });

    test('targetType "service" roundtrips correctly', () async {
      final report = _makeReport(
        id: 'report_service',
        targetType: 'service',
        targetId: 'service_123',
      );
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.targetType, 'service');
    });

    test('targetType "message" roundtrips correctly', () async {
      final report = _makeReport(
        id: 'report_message',
        targetType: 'message',
        targetId: 'msg_456',
      );
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.targetType, 'message');
    });
  });

  group('Report serialization - reason field', () {
    test('reason is preserved verbatim', () async {
      final report = _makeReport(reason: 'Fraude suspectée');
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.reason, 'Fraude suspectée');
    });
  });

  group('Report serialization - details null / non-null', () {
    test('null details roundtrips as null', () async {
      final report = _makeReport(details: null);
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.details, isNull);
    });

    test('non-null details roundtrips correctly', () async {
      final report = _makeReport(
        id: 'report_with_details',
        details: 'Contexte supplémentaire ici.',
      );
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.details, 'Contexte supplémentaire ici.');
    });
  });

  group('Report serialization - status values', () {
    test('status "open" roundtrips correctly', () async {
      final report = _makeReport(status: 'open');
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.status, 'open');
    });

    test('status "resolved" roundtrips correctly', () async {
      final report = _makeReport(id: 'report_resolved', status: 'resolved');
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.status, 'resolved');
    });

    test('status "dismissed" roundtrips correctly', () async {
      final report = _makeReport(id: 'report_dismissed', status: 'dismissed');
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;
      expect(result.status, 'dismissed');
    });
  });

  group('Report serialization - createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 7, 10, 16, 0, 0).toUtc();
      final report = _makeReport(createdAt: t);
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);
      final result = (await col.doc(report.id).get()).data()!;

      expect(result.createdAt.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
    });

    test('createdAt is stored as Firestore Timestamp', () async {
      final report = _makeReport();
      final col = FirestoreCollections.reports(fakeDb);
      await col.doc(report.id).set(report);

      final raw = (await fakeDb.collection('reports').doc(report.id).get())
          .data()!;
      expect(raw['createdAt'], isA<Timestamp>());
    });
  });

  group('Report serialization - safe defaults for missing fields', () {
    test('missing fields do not crash and use safe defaults', () async {
      await fakeDb.collection('reports').doc('minimal').set({
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.reports(fakeDb);
      final result = (await col.doc('minimal').get()).data()!;

      expect(result.reporterId, '');
      expect(result.targetType, 'user');
      expect(result.targetId, '');
      expect(result.reason, '');
      expect(result.details, isNull);
      expect(result.status, 'open');
    });
  });
}
