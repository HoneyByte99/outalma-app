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
import 'package:outalma_app/src/domain/enums/gender.dart';
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
  Gender? gender,
  String? avatarId,
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
    gender: gender,
    avatarId: avatarId,
  );
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('AppUser serialization - all fields populated', () {
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

  group('AppUser serialization - minimal fields (nulls)', () {
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

  group('AppUser serialization - activeMode enum', () {
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

  group('AppUser serialization - displayName fallback', () {
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

  group('AppUser serialization - createdAt timestamp', () {
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

  group('AppUser serialization - country default', () {
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

  // The declared gender. Collected at sign-up on both paths, drawn as a
  // pictogram on two public surfaces, and absent from every one of the 50
  // accounts that exist today, which is why the null case is tested first.
  group('AppUser serialization - declared gender', () {
    test('both values roundtrip through their canonical string', () async {
      for (final (gender, stored) in [
        (Gender.male, 'male'),
        (Gender.female, 'female'),
      ]) {
        final user = _makeUser(id: 'u_$stored', gender: gender);
        final col = FirestoreCollections.users(fakeDb);
        await col.doc(user.id).set(user);

        final raw = (await fakeDb.collection('users').doc(user.id).get())
            .data()!;
        expect(raw['gender'], stored);

        final result = (await col.doc(user.id).get()).data()!;
        expect(result.gender, gender);
      }
    });

    test(
      'a document written before the field existed reads back null',
      () async {
        // The production case: all 50 accounts. Reading a default here would
        // print a pictogram claiming a gender nobody declared.
        await fakeDb.collection('users').doc('legacy').set({
          'displayName': 'Moussa',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
        });
        final col = FirestoreCollections.users(fakeDb);
        final result = (await col.doc('legacy').get()).data()!;
        expect(result.gender, isNull);
      },
    );

    test(
      'a null gender is OMITTED from the map, never written as null',
      () async {
        // Same hazard as pushToken: switchMode and updateProfile both merge-write
        // the whole AppUser, and an explicit null would erase a declared gender
        // whenever the in-memory copy is stale.
        final user = _makeUser(id: 'no_gender');
        final col = FirestoreCollections.users(fakeDb);
        await col.doc(user.id).set(user);

        final raw = (await fakeDb.collection('users').doc(user.id).get())
            .data()!;
        expect(raw.containsKey('gender'), isFalse);
      },
    );

    test(
      'a legacy or foreign value reads back null, not a nearest match',
      () async {
        // The 2024 FlutterFlow export used the same key with another vocabulary.
        for (final value in ['Homme', 'M', 'other', 42]) {
          final id = 'legacy_$value';
          await fakeDb.collection('users').doc(id).set({
            'displayName': 'X',
            'gender': value,
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
          });
          final result = (await FirestoreCollections.users(
            fakeDb,
          ).doc(id).get()).data()!;
          expect(result.gender, isNull, reason: 'gender="$value"');
        }
      },
    );
  });

  // The illustrated avatar. Same shape of problem as the declared gender: an
  // optional field mirrored into a world-readable projection, absent from every
  // account that exists today.
  group('AppUser serialization - illustrated avatar', () {
    test('a catalogue id roundtrips', () async {
      final user = _makeUser(id: 'u_av', avatarId: 'human_afro1_t2');
      final col = FirestoreCollections.users(fakeDb);
      await col.doc(user.id).set(user);

      final raw = (await fakeDb.collection('users').doc(user.id).get()).data()!;
      expect(raw['avatarId'], 'human_afro1_t2');

      final result = (await col.doc(user.id).get()).data()!;
      expect(result.avatarId, 'human_afro1_t2');
    });

    test(
      'a null avatarId is OMITTED from the map, never written as null',
      () async {
        // Same hazard as pushToken and gender: upsert merge-writes the whole
        // AppUser, so an explicit null would erase an avatar chosen on another
        // device. Erasing goes through setProfileImage instead.
        final user = _makeUser(id: 'no_avatar');
        final col = FirestoreCollections.users(fakeDb);
        await col.doc(user.id).set(user);

        final raw = (await fakeDb.collection('users').doc(user.id).get())
            .data()!;
        expect(raw.containsKey('avatarId'), isFalse);
      },
    );

    test('a NON-STRING value reads back null instead of throwing', () async {
      // This is a guard on the authentication path, not a nicety. The bare
      // `as String?` idiom used by the neighbouring fields would throw inside
      // the converter, _resolveState would swallow it and return
      // AuthUnauthenticated, and the owner would be signed out of their own
      // account by a bad value in a decorative field.
      final bad = <Object>[
        42,
        true,
        <String, Object>{'tone': 3},
        <String>['human_afro1'],
      ];
      for (var i = 0; i < bad.length; i++) {
        final id = 'bad_$i';
        await fakeDb.collection('users').doc(id).set({
          'displayName': 'Awa',
          'avatarId': bad[i],
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
        });
        final snap = await FirestoreCollections.users(fakeDb).doc(id).get();
        expect(snap.data, returnsNormally, reason: '${bad[i]} must not throw');
        expect(snap.data()!.avatarId, isNull);
      }
    });

    test(
      'a document written before the field existed reads back null',
      () async {
        await fakeDb.collection('users').doc('legacy_av').set({
          'displayName': 'Moussa',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1).toUtc()),
        });
        final col = FirestoreCollections.users(fakeDb);
        final result = (await col.doc('legacy_av').get()).data()!;
        expect(result.avatarId, isNull);
      },
    );
  });
}
