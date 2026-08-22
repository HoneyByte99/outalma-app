import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/repositories/firestore_identity_trust_repository.dart';
import 'package:outalma_app/src/domain/enums/identity_trust_status.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreIdentityTrustRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreIdentityTrustRepository(db);
  });

  Future<void> write(Map<String, Object?> data) =>
      db.collection('provider_trust').doc('p1').set(data);

  test('emits null when the document does not exist', () async {
    // The majority case at launch, and NOT an error: absence is the third
    // public state, "not verified".
    expect(await repo.watch('p1').first, isNull);
  });

  test('emits verified', () async {
    await write({'identityStatus': 'verified'});
    expect(await repo.watch('p1').first, IdentityTrustStatus.verified);
  });

  test('emits pending', () async {
    await write({'identityStatus': 'pending'});
    expect(await repo.watch('p1').first, IdentityTrustStatus.pending);
  });

  test('emits null for an unknown status rather than guessing', () async {
    // A value this client does not understand must never become a badge. The
    // trust signal fails closed: unknown reads as "not verified".
    await write({'identityStatus': 'approved_maybe'});
    expect(await repo.watch('p1').first, isNull);
  });

  test('emits null when the field is missing entirely', () async {
    await write({'updatedAt': 'whenever'});
    expect(await repo.watch('p1').first, isNull);
  });

  test('follows the document as the server changes it', () async {
    final seen = <IdentityTrustStatus?>[];
    final sub = repo.watch('p1').listen(seen.add);

    await write({'identityStatus': 'pending'});
    await Future<void>.delayed(Duration.zero);
    await write({'identityStatus': 'verified'});
    await Future<void>.delayed(Duration.zero);
    await db.collection('provider_trust').doc('p1').delete();
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    // The revocation path matters most: the badge has to disappear on its own,
    // without the client reloading anything.
    expect(seen.last, isNull);
    expect(seen, contains(IdentityTrustStatus.pending));
    expect(seen, contains(IdentityTrustStatus.verified));
  });

  test('reads the document of the requested provider, not another', () async {
    await write({'identityStatus': 'verified'});
    expect(await repo.watch('p2').first, isNull);
  });
}
