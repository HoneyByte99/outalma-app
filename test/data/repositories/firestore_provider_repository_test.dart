import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/repositories/firestore_provider_repository.dart';
import 'package:outalma_app/src/domain/models/blocked_slot.dart';
import 'package:outalma_app/src/domain/models/provider_profile.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreProviderRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreProviderRepository(db);
  });

  ProviderProfile profile({
    bool active = true,
    bool suspended = false,
    String? bio,
    DateTime? createdAt,
  }) => ProviderProfile(
    uid: 'p1',
    bio: bio,
    serviceArea: 'Dakar',
    serviceAreaLat: 14.7,
    serviceAreaLng: -17.4,
    active: active,
    suspended: suspended,
    createdAt: createdAt ?? DateTime(2024, 1, 1).toUtc(),
  );

  Future<Map<String, dynamic>> rawDoc() async {
    final snap = await db.collection('providers').doc('p1').get();
    return snap.data()!;
  }

  group('upsert (create)', () {
    test(
      'writes the full document including active/suspended/createdAt',
      () async {
        await repo.upsert(profile(active: true, suspended: false, bio: 'Hi'));

        final data = await rawDoc();
        expect(data['active'], true);
        expect(data['suspended'], false);
        expect(data['bio'], 'Hi');
        expect(data['createdAt'], isNotNull);
        expect(data['serviceArea'], 'Dakar');
      },
    );
  });

  group('upsert (update)', () {
    test('a bio edit never touches server-managed fields', () async {
      // Provider exists and was suspended by moderation, with an old createdAt.
      final created = DateTime(2023, 5, 1).toUtc();
      await repo.upsert(
        profile(active: true, suspended: false, bio: 'Old', createdAt: created),
      );
      // Moderation suspends them out-of-band (Admin SDK would set this).
      await db.collection('providers').doc('p1').update({'suspended': true});

      // The client re-saves onboarding, which hardcodes active:true/suspended:false
      // and a fresh createdAt. None of that must reach the document.
      await repo.upsert(
        profile(
          active: true,
          suspended: false,
          bio: 'New bio',
          createdAt: DateTime(2026, 1, 1).toUtc(),
        ),
      );

      final data = await rawDoc();
      expect(data['bio'], 'New bio', reason: 'editable field updates');
      expect(data['suspended'], true, reason: 'moderation flag preserved');
      expect((data['createdAt'] as dynamic), isNotNull);
      // createdAt must remain the original, not be reset to 2026.
      final readBack = await FirestoreCollections.providers(db).doc('p1').get();
      expect(
        readBack.data()!.createdAt,
        created,
        reason: 'createdAt not reset on edit',
      );
      expect(readBack.data()!.suspended, true);
    });

    test('clearing bio to null is persisted', () async {
      await repo.upsert(profile(bio: 'Something'));
      await repo.upsert(profile(bio: null));

      final data = await rawDoc();
      expect(data['bio'], isNull);
    });
  });

  group('watchByUid', () {
    test('emits the profile, then null when it does not exist', () async {
      await repo.upsert(profile(bio: 'Hi'));
      expect((await repo.watchByUid('p1').first)?.bio, 'Hi');
      expect(await repo.watchByUid('missing').first, isNull);
    });
  });

  group('watchAll', () {
    test('returns only active, non-suspended providers', () async {
      Future<void> seed(
        String uid, {
        required bool active,
        required bool suspended,
      }) => db.collection('providers').doc(uid).set({
        'uid': uid,
        'active': active,
        'suspended': suspended,
        'createdAt': DateTime(2024, 1, 1).toUtc(),
      });
      await seed('live', active: true, suspended: false);
      await seed('paused', active: false, suspended: false);
      await seed('banned', active: true, suspended: true);

      final list = await repo.watchAll().first;
      expect(list.map((p) => p.uid), ['live']);
    });
  });

  group('blocked slots', () {
    test('add, watch (ordered by date) and remove', () async {
      await repo.addBlockedSlot(
        'p1',
        BlockedSlot(id: 'ignored', date: DateTime(2026, 3, 2).toUtc()),
      );
      await repo.addBlockedSlot(
        'p1',
        BlockedSlot(
          id: 'ignored',
          date: DateTime(2026, 3, 1).toUtc(),
          reason: 'Congé',
        ),
      );

      var slots = await repo.watchBlockedSlots('p1').first;
      expect(slots, hasLength(2));
      // Ordered ascending by date.
      expect(slots.first.date, DateTime(2026, 3, 1).toUtc());
      expect(slots.first.reason, 'Congé');

      await repo.removeBlockedSlot('p1', slots.first.id);
      slots = await repo.watchBlockedSlots('p1').first;
      expect(slots, hasLength(1));
      expect(slots.first.date, DateTime(2026, 3, 2).toUtc());
    });
  });
}
