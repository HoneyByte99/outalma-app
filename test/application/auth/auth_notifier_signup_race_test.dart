// Reproduces the sign-up name race reported on a real device: the name
// typed at sign-up does not survive into the profile.
//
// Root cause under test: `createUserWithEmailAndPassword` fires
// `authStateChanges` IMMEDIATELY, before `updateDisplayName` and before the
// explicit Firestore upsert carrying the real name. The auth listener
// (`AuthNotifier._resolveState`) reacts to that early event and, finding no
// Firestore doc yet, writes a defensive minimal one with
// `displayName: firebaseUser.displayName ?? ''`. If that write lands AFTER
// the real upsert, a naive merge write clobbers the name with ''.
//
// The gate below does not rely on winning an incidental scheduling race: it
// specifically holds back any upsert whose `displayName` is empty (the exact
// signature of the listener's defensive write) until the test releases it,
// so the "listener writes last" scenario is reproduced deterministically.

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/data/firestore/firestore_collections.dart';
import 'package:outalma_app/src/data/repositories/firestore_user_repository.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/repositories/user_repository.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

/// Delays any upsert carrying an empty `displayName` - the defensive
/// listener write's signature - until the test calls [release]. Lets the
/// test force "the listener's write lands last" without depending on which
/// async chain happens to reach `upsert` first.
class _GatedUserRepository implements UserRepository {
  _GatedUserRepository(this._inner);
  final UserRepository _inner;

  Completer<void>? _gate;

  void pauseNextEmptyNameUpsert() => _gate = Completer<void>();

  // Deliberately does NOT clear `_gate`: the field must stay set so a
  // `release()` called from the test after `upsert` has already started
  // awaiting it can still reach the SAME completer. Clearing it here (racing
  // with `upsert`'s own read of the field) is what silently no-oped `release`
  // and let the paused write hang forever, unobserved, in an earlier version
  // of this harness - the test then read Firestore before that write ever
  // landed and passed for the wrong reason.
  void release() => _gate?.complete();

  @override
  Future<void> upsert(AppUser user) async {
    if (user.displayName.isEmpty && _gate != null) {
      await _gate!.future;
    }
    await _inner.upsert(user);
  }

  @override
  Future<AppUser?> getById(String userId) => _inner.getById(userId);

  @override
  Stream<AppUser?> watchById(String userId) => _inner.watchById(userId);

  @override
  Future<void> setProfileImage({
    required String userId,
    required String? photoPath,
    required String? avatarId,
  }) => _inner.setProfileImage(
    userId: userId,
    photoPath: photoPath,
    avatarId: avatarId,
  );
}

void main() {
  const uid = 'uid-signup-race';

  late FakeFirebaseFirestore fakeDb;
  late _GatedUserRepository gatedRepo;
  late _MockFirebaseAuth mockAuth;
  late _MockUser mockUser;
  late _MockUserCredential mockCredential;
  late StreamController<User?> authController;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    gatedRepo = _GatedUserRepository(FirestoreUserRepository(fakeDb));

    authController = StreamController<User?>.broadcast();

    mockUser = _MockUser();
    when(() => mockUser.uid).thenReturn(uid);
    when(() => mockUser.email).thenReturn('signup-race@test.example');
    // Modeling the worst case the bug report requires: the Auth SDK's local
    // profile cache for this user is never observed to carry the name within
    // this test's window (a real `updateDisplayName` is a network round trip
    // and is not guaranteed to have landed locally by the time the listener
    // reads it). If it DID land in time the listener would write the correct
    // name too, and there would be no bug to reproduce - measured directly:
    // wiring updateDisplayName to mutate a shared field the getter reads
    // let the fake's `updateDisplayName` resolve (and update the field)
    // before the listener's own `getById` round trip, which never exercised
    // the empty-name branch at all and made this test pass vacuously.
    when(() => mockUser.displayName).thenReturn(null);
    when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async {});
    when(() => mockUser.sendEmailVerification(any())).thenAnswer((_) async {});

    mockCredential = _MockUserCredential();
    when(() => mockCredential.user).thenReturn(mockUser);

    mockAuth = _MockFirebaseAuth();
    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer((_) => authController.stream);
    when(
      () => mockAuth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      // The auth listener reacts to this BEFORE updateDisplayName and the
      // explicit upsert run, exactly like the real SDK.
      authController.add(mockUser);
      return mockCredential;
    });
  });

  tearDown(() async {
    await authController.close();
  });

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(mockAuth),
      userRepositoryProvider.overrideWithValue(gatedRepo),
    ],
  );

  test(
    'a late auth-listener write must not blank the name sign-up just stored',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      // Resolve the initial (signed-out) state first, like the real app does
      // at startup, before the user ever attempts to sign up. `read(...future)`
      // triggers `build()` - and its synchronous `.listen()` call - before the
      // event is emitted, so a broadcast stream with no prior listener does
      // not drop it.
      final initialState = container.read(authNotifierProvider.future);
      authController.add(null);
      await initialState;

      // Arm the gate: the listener's defensive write (empty displayName)
      // will now block until release(), guaranteeing it lands after the
      // explicit upsert below - the exact ordering the bug report describes.
      gatedRepo.pauseNextEmptyNameUpsert();

      await container
          .read(authNotifierProvider.notifier)
          .signUpWithEmailPassword(
            displayName: 'Real Name',
            email: 'signup-race@test.example',
            password: 'S3cret!!',
            gender: Gender.female,
          );

      gatedRepo.release();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final stored = await FirestoreCollections.users(fakeDb).doc(uid).get();
      expect(
        stored.data()?.displayName,
        'Real Name',
        reason:
            'the auth listener must not be able to blank a name it never knew',
      );
    },
  );

  test(
    'the same late write does not touch gender or the consent proof',
    () async {
      // Collateral-damage check requested alongside the name race: gender
      // and termsAcceptedAt are ALREADY guarded in `_userToFirestore` (only
      // serialized `if (user.gender != null)` / `if (user.termsAcceptedAt !=
      // null)`), so the defensive doc (which carries neither) should never
      // erase them, independently of the displayName fix. This test protects
      // that fact from regressing.
      final container = buildContainer();
      addTearDown(container.dispose);

      final initialState = container.read(authNotifierProvider.future);
      authController.add(null);
      await initialState;

      gatedRepo.pauseNextEmptyNameUpsert();

      await container
          .read(authNotifierProvider.notifier)
          .signUpWithEmailPassword(
            displayName: 'Real Name',
            email: 'signup-race@test.example',
            password: 'S3cret!!',
            gender: Gender.female,
          );

      gatedRepo.release();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final stored = await FirestoreCollections.users(fakeDb).doc(uid).get();
      expect(stored.data()?.gender, Gender.female);
      expect(stored.data()?.termsAcceptedAt, isNotNull);
    },
  );
}
