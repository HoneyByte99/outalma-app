// Verifies that AppUser objects survive a Firestore write+read roundtrip
// without data loss or silent type coercions.
//
// Critical cases:
//   - activeMode enum (client / provider) stored as string
//   - displayName fallback to empty string when field absent
//   - Optional fields (photoPath, phoneE164, pushToken) null / non-null
//   - createdAt Timestamp ↔ DateTime conversion

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

AppUser _makeUser({
  String id = 'user_1',
  String displayName = 'Fatou Diallo',
  String email = 'fatou@example.com',
  String country = 'SN',
  ActiveMode activeMode = ActiveMode.client,
  String? photoPath,
  String? phoneE164,
  String? pushToken,
  DateTime? createdAt,
}) {
  return AppUser(
    id: id,
    displayName: displayName,
    email: email,
    country: country,
    activeMode: activeMode,
    photoPath: photoPath,
    phoneE164: phoneE164,
    pushToken: pushToken,
    createdAt: createdAt ?? DateTime(2024, 1, 15, 10, 0).toUtc(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('AppUser serialization — all fields populated', () {
    test('roundtrip preserves all fields', () async {
      final user = _makeUser(
        photoPath: 'gs://bucket/photo.jpg',
        phoneE164: '+221770000001',
        pushToken: 'fcm_token_abc',
      );
      final col = FirestoreCollections.users(fakeDb);
      await col.doc(user.id).set(user);
      final result = (await col.doc(user.id).get()).data()!;

      expect(result.id, user.id);
      expect(result.displayName, 'Fatou Diallo');
      expect(result.email, 'fatou@example.com');
      expect(result.country, 'SN');
      expect(result.activeMode, ActiveMode.client);
      expect(result.photoPath, 'gs://bucket/photo.jpg');
      expect(result.phoneE164, '+221770000001');
      expect(result.pushToken, 'fcm_token_abc');
    });
  });

  group('AppUser serialization — minimal fields (nulls)', () {
    test('roundtrip with null optional fields does not crash', () async {
      final user = _makeUser(); // no photoPath, phoneE164, pushToken
      final col = FirestoreCollections.users(fakeDb);
      await col.doc(user.id).set(user);
      final result = (await col.doc(user.id).get()).data()!;

      expect(result.photoPath, isNull);
      // phoneE164 is intentionally omitted from the map when null (security rule).
      expect(result.phoneE164, isNull);
      expect(result.pushToken, isNull);
    });
  });

  group('AppUser serialization — activeMode enum', () {
    test('client mode roundtrips as "client" string', () async {
      final user = _makeUser(activeMode: ActiveMode.client);
      final col = FirestoreCollections.users(fakeDb);
      await col.doc(user.id).set(user);

      // Check raw string stored in Firestore
      final raw = (await fakeDb.collection('users').doc(user.id).get()).data()!;
      expect(raw['activeMode'], 'client');

      final result = (await col.doc(user.id).get()).data()!;
      expect(result.activeMode, ActiveMode.client);
    });

    test('provider mode roundtrips as "provider" string', () async {
      final user = _makeUser(activeMode: ActiveMode.provider);
      final col = FirestoreCollections.users(fakeDb);
      await col.doc(user.id).set(user);

      final raw = (await fakeDb.collection('users').doc(user.id).get()).data()!;
      expect(raw['activeMode'], 'provider');

      final result = (await col.doc(user.id).get()).data()!;
      expect(result.activeMode, ActiveMode.provider);
    });

    test('unknown activeMode string falls back to client', () async {
      await fakeDb.collection('users').doc('bad_mode').set({
        'displayName': 'Test',
        'activeMode': 'unknown_value',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.users(fakeDb);
      final result = (await col.doc('bad_mode').get()).data()!;
      expect(result.activeMode, ActiveMode.client);
    });
  });

  group('AppUser serialization — displayName fallback', () {
    test('missing displayName field returns empty string', () async {
      await fakeDb.collection('users').doc('no_name').set({
        'email': 'x@x.com',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.users(fakeDb);
      final result = (await col.doc('no_name').get()).data()!;
      expect(result.displayName, '');
    });
  });

  group('AppUser serialization — createdAt timestamp', () {
    test('createdAt roundtrips with millisecond precision', () async {
      final t = DateTime(2024, 6, 20, 9, 30, 0).toUtc();
      final user = _makeUser(createdAt: t);
      final col = FirestoreCollections.users(fakeDb);
      await col.doc(user.id).set(user);
      final result = (await col.doc(user.id).get()).data()!;

      expect(result.createdAt.millisecondsSinceEpoch, t.millisecondsSinceEpoch);
    });

    test(
      'createdAt is stored as Firestore Timestamp (not String/int)',
      () async {
        final user = _makeUser();
        final col = FirestoreCollections.users(fakeDb);
        await col.doc(user.id).set(user);

        final raw = (await fakeDb.collection('users').doc(user.id).get())
            .data()!;
        expect(raw['createdAt'], isA<Timestamp>());
      },
    );

    test('missing createdAt field returns epoch (does not crash)', () async {
      await fakeDb.collection('users').doc('no_ts').set({
        'displayName': 'Alice',
      });
      final col = FirestoreCollections.users(fakeDb);
      final result = (await col.doc('no_ts').get()).data()!;
      expect(result.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('AppUser serialization — country default', () {
    test('missing country field defaults to FR', () async {
      await fakeDb.collection('users').doc('no_country').set({
        'displayName': 'Marc',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
      });
      final col = FirestoreCollections.users(fakeDb);
      final result = (await col.doc('no_country').get()).data()!;
      expect(result.country, 'FR');
    });
  });
}
