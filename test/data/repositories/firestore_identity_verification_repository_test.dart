import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_identity_verification_repository.dart';
import 'package:outalma_app/src/domain/enums/identity_status.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreIdentityVerificationRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreIdentityVerificationRepository(db);
  });

  Future<void> write(String id, Map<String, Object?> data) =>
      db.collection('identity_verifications').doc(id).set(data);

  test('emits null when the provider has no file', () async {
    expect(await repo.watchLatest('p1').first, isNull);
  });

  test('emits nothing for an empty uid without querying', () async {
    // An empty uid must not run a query; the stream stays empty (never a value).
    expect(await repo.watchLatest('').isEmpty, isTrue);
  });

  test('maps the stored fields of a pending file', () async {
    await write('v1', {
      'providerId': 'p1',
      'status': 'pending',
      'attempt': 1,
      'priority': false,
      'rejectionReason': null,
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20, 9)),
      'reviewedAt': null,
    });
    final record = await repo.watchLatest('p1').first;
    expect(record, isNotNull);
    expect(record!.status, IdentityStatus.pending);
    expect(record.attempt, 1);
    expect(record.priority, isFalse);
    expect(record.rejectionReason, isNull);
    expect(record.submittedAt, DateTime.utc(2026, 8, 20, 9));
    expect(record.reviewedAt, isNull);
  });

  test('maps a rejected file with its reason and reviewed date', () async {
    await write('v1', {
      'providerId': 'p1',
      'status': 'rejected',
      'attempt': 2,
      'priority': false,
      'rejectionReason': 'Verso illisible.',
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
      'reviewedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 21)),
    });
    final record = await repo.watchLatest('p1').first;
    expect(record!.status, IdentityStatus.rejected);
    expect(record.attempt, 2);
    expect(record.rejectionReason, 'Verso illisible.');
    expect(record.reviewedAt, DateTime.utc(2026, 8, 21));
  });

  test('an unknown status falls to none rather than blanking', () async {
    await write('v1', {
      'providerId': 'p1',
      'status': 'archived_someday',
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    });
    final record = await repo.watchLatest('p1').first;
    expect(record!.status, IdentityStatus.none);
    // Defaults hold when the optional fields are absent.
    expect(record.attempt, 1);
    expect(record.priority, isFalse);
  });

  test('returns the most recent file, by submittedAt descending', () async {
    await write('old', {
      'providerId': 'p1',
      'status': 'rejected',
      'attempt': 1,
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
    });
    await write('new', {
      'providerId': 'p1',
      'status': 'pending',
      'attempt': 2,
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    });
    final record = await repo.watchLatest('p1').first;
    // The latest attempt wins: the status screen shows the current file.
    expect(record!.status, IdentityStatus.pending);
    expect(record.attempt, 2);
  });

  test('reads only the requested provider, never another', () async {
    await write('v1', {
      'providerId': 'p1',
      'status': 'approved',
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    });
    expect(await repo.watchLatest('p2').first, isNull);
  });
}
