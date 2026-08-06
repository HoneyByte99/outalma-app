// Tests AuthNotifier business logic with test doubles that bypass live
// Firebase. Two styles coexist:
//
//   * switchMode / updateProfile use a subclass that overrides build() to
//     return a fixed authenticated state (no auth stream needed).
//   * Everything else drives the REAL notifier with a mocked FirebaseAuth
//     (authStateChanges via a StreamController), a mocked CallableFunctionClient
//     (injected through callableFunctionClientProvider), a mocked
//     UserRepository and a FakeFirebaseFirestore, so _resolveState, sign-up,
//     phone auth and email verification are exercised end-to-end.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/data/services/callable_function_client.dart';
import 'package:outalma_app/src/data/services/callable_function_client_provider.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/repositories/user_repository.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockUserRepository extends Mock implements UserRepository {}

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

class _MockClient extends Mock implements CallableFunctionClient {}

/// Bypasses FirebaseAuth by returning a fixed state from build().
class _AuthenticatedNotifier extends AuthNotifier {
  _AuthenticatedNotifier(this._user);
  final AppUser _user;

  @override
  Future<AuthState> build() async => AuthAuthenticated(_user);
}

class _UnauthenticatedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppUser _makeUser({
  String id = 'user_1',
  String displayName = 'Alice',
  String? phoneE164,
  ActiveMode activeMode = ActiveMode.client,
}) {
  return AppUser(
    id: id,
    displayName: displayName,
    email: 'alice@test.com',
    country: 'FR',
    activeMode: activeMode,
    phoneE164: phoneE164,
    createdAt: DateTime(2024, 1, 1).toUtc(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_makeUser());
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(ActionCodeSettings(url: 'https://example.com'));
  });

  // -------------------------------------------------------------------------
  // switchMode / updateProfile (fixed-state subclass style)
  // -------------------------------------------------------------------------

  group('AuthNotifier.switchMode / updateProfile', () {
    late _MockUserRepository mockRepo;

    ProviderContainer authedContainer(AppUser user) => ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => _AuthenticatedNotifier(user)),
        userRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );

    setUp(() {
      mockRepo = _MockUserRepository();
    });

    test('switchMode updates state optimistically and upserts', () async {
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      final container = authedContainer(_makeUser());
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .switchMode(ActiveMode.provider);

      final state = container.read(authNotifierProvider).valueOrNull;
      expect((state as AuthAuthenticated).user.activeMode, ActiveMode.provider);
      verify(() => mockRepo.upsert(any())).called(1);
    });

    test('switchMode reverts state when upsert throws', () async {
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Network error'));
      final container = authedContainer(_makeUser());
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .switchMode(ActiveMode.provider),
        throwsA(isA<Exception>()),
      );
      final state = container.read(authNotifierProvider).valueOrNull;
      expect((state as AuthAuthenticated).user.activeMode, ActiveMode.client);
    });

    test('switchMode does nothing when unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UnauthenticatedNotifier()),
          userRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .switchMode(ActiveMode.provider);
      verifyNever(() => mockRepo.upsert(any()));
    });

    test(
      'updateProfile updates displayName + country and keeps phone',
      () async {
        when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
        final container = authedContainer(_makeUser(phoneE164: '+33600000000'));
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.future);
        await container
            .read(authNotifierProvider.notifier)
            .updateProfile(displayName: 'Bob', country: 'SN');

        final user =
            (container.read(authNotifierProvider).valueOrNull
                    as AuthAuthenticated)
                .user;
        expect(user.displayName, 'Bob');
        expect(user.country, 'SN');
        expect(user.phoneE164, '+33600000000');
      },
    );

    test('updateProfile reverts state on upsert failure', () async {
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Write failed'));
      final container = authedContainer(_makeUser());
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .updateProfile(displayName: 'Bob'),
        throwsA(isA<Exception>()),
      );
      final user =
          (container.read(authNotifierProvider).valueOrNull
                  as AuthAuthenticated)
              .user;
      expect(user.displayName, 'Alice');
    });

    test('updateProfile does nothing when unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UnauthenticatedNotifier()),
          userRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(displayName: 'Bob');
      verifyNever(() => mockRepo.upsert(any()));
    });
  });

  // -------------------------------------------------------------------------
  // Real notifier driven by mocked FirebaseAuth
  // -------------------------------------------------------------------------

  group('AuthNotifier (real build) - auth stream + Cloud Functions', () {
    late _MockAuth auth;
    late _MockUserRepository repo;
    late _MockClient client;
    late FakeFirebaseFirestore fakeDb;
    late StreamController<User?> authStream;

    setUp(() {
      auth = _MockAuth();
      repo = _MockUserRepository();
      client = _MockClient();
      fakeDb = FakeFirebaseFirestore();
      authStream = StreamController<User?>();

      when(() => auth.authStateChanges()).thenAnswer((_) => authStream.stream);
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => repo.upsert(any())).thenAnswer((_) async {});
      when(
        () => client.call(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => <String, dynamic>{});
    });

    tearDown(() async {
      await authStream.close();
    });

    ProviderContainer makeContainer() {
      final c = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(repo),
          callableFunctionClientProvider.overrideWithValue(client),
          firestoreProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    /// Builds the notifier and resolves the initial state for [firstEvent].
    Future<(ProviderContainer, AuthState)> buildWith(User? firstEvent) async {
      final c = makeContainer();
      final future = c.read(authNotifierProvider.future);
      authStream.add(firstEvent);
      final state = await future;
      return (c, state);
    }

    _MockUser makeFirebaseUser({
      String uid = 'uid_1',
      String? displayName = 'Alice',
      String? email = 'alice@test.com',
    }) {
      final u = _MockUser();
      when(() => u.uid).thenReturn(uid);
      when(() => u.displayName).thenReturn(displayName);
      when(() => u.email).thenReturn(email);
      when(() => u.updateDisplayName(any())).thenAnswer((_) async {});
      when(() => u.sendEmailVerification(any())).thenAnswer((_) async {});
      when(() => u.delete()).thenAnswer((_) async {});
      when(() => u.reload()).thenAnswer((_) async {});
      return u;
    }

    // ---- build / _resolveState -------------------------------------------

    test('resolves to unauthenticated when firebase user is null', () async {
      final (_, state) = await buildWith(null);
      expect(state, isA<AuthUnauthenticated>());
    });

    test('resolves to authenticated when repo returns a user', () async {
      final appUser = _makeUser(id: 'uid_1');
      when(() => repo.getById('uid_1')).thenAnswer((_) async => appUser);
      final (_, state) = await buildWith(makeFirebaseUser());
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.id, 'uid_1');
    });

    test('retries a transient read failure before succeeding', () async {
      var attempts = 0;
      when(() => repo.getById('uid_1')).thenAnswer((_) async {
        attempts++;
        if (attempts < 2) throw Exception('network blip');
        return _makeUser(id: 'uid_1');
      });
      final (_, state) = await buildWith(makeFirebaseUser());
      expect(state, isA<AuthAuthenticated>());
      expect(attempts, greaterThanOrEqualTo(2));
    });

    test('creates a defensive minimal doc when none exists', () async {
      when(() => repo.getById('uid_1')).thenAnswer((_) async => null);
      final (_, state) = await buildWith(makeFirebaseUser());
      expect(state, isA<AuthAuthenticated>());
      final captured =
          verify(() => repo.upsert(captureAny())).captured.single as AppUser;
      expect(captured.id, 'uid_1');
      expect(captured.phoneE164, isNull, reason: 'phone is never client-set');
    });

    test('falls back to unauthenticated when reads keep failing', () async {
      when(() => repo.getById('uid_1')).thenThrow(Exception('down'));
      final (_, state) = await buildWith(makeFirebaseUser());
      expect(state, isA<AuthUnauthenticated>());
    });

    test('later auth emissions update the state', () async {
      when(
        () => repo.getById('uid_1'),
      ).thenAnswer((_) async => _makeUser(id: 'uid_1'));
      final (c, first) = await buildWith(null);
      expect(first, isA<AuthUnauthenticated>());
      authStream.add(makeFirebaseUser());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        c.read(authNotifierProvider).valueOrNull,
        isA<AuthAuthenticated>(),
      );
    });

    // ---- signOut ---------------------------------------------------------

    test('signOut clears pushToken then signs out', () async {
      await fakeDb.collection('users').doc('uid_1').set({'pushToken': 'tok'});
      final fbUser = makeFirebaseUser();
      when(() => auth.currentUser).thenReturn(fbUser);
      final (c, _) = await buildWith(null);

      await c.read(authNotifierProvider.notifier).signOut();

      final doc = await fakeDb.collection('users').doc('uid_1').get();
      expect(doc.data()!.containsKey('pushToken'), isFalse);
      verify(() => auth.signOut()).called(1);
    });

    test('signOut still signs out when there is no current user', () async {
      when(() => auth.currentUser).thenReturn(null);
      final (c, _) = await buildWith(null);
      await c.read(authNotifierProvider.notifier).signOut();
      verify(() => auth.signOut()).called(1);
    });

    // ---- deleteAccount / exportMyData ------------------------------------

    test('deleteAccount calls the CF then signs out', () async {
      final (c, _) = await buildWith(null);
      await c.read(authNotifierProvider.notifier).deleteAccount();
      verify(
        () => client.call('deleteMyAccount', data: any(named: 'data')),
      ).called(1);
      verify(() => auth.signOut()).called(1);
    });

    test('exportMyData returns the CF payload', () async {
      when(
        () => client.call('exportMyData', data: any(named: 'data')),
      ).thenAnswer((_) async => {'user': 'x'});
      final (c, _) = await buildWith(null);
      final data = await c.read(authNotifierProvider.notifier).exportMyData();
      expect(data['user'], 'x');
    });

    // ---- phone auth ------------------------------------------------------

    test('requestPhoneOtp forwards phone + channel', () async {
      final (c, _) = await buildWith(null);
      await c
          .read(authNotifierProvider.notifier)
          .requestPhoneOtp('+33600000000', channel: 'call');
      final captured =
          verify(
                () => client.call(
                  'requestPhoneOtp',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map;
      expect(captured['phone'], '+33600000000');
      expect(captured['channel'], 'call');
    });

    test('phoneSignInWithOtp returns not-signed-in for a new user', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignIn', data: any(named: 'data')),
      ).thenAnswer((_) async => {'newUser': true});
      final (c, _) = await buildWith(null);
      final result = await c
          .read(authNotifierProvider.notifier)
          .phoneSignInWithOtp('+33600000000', '123456');
      expect(result.signedIn, isFalse);
      expect(result.isNewUser, isTrue);
    });

    test(
      'phoneSignInWithOtp signs in with the returned custom token',
      () async {
        when(
          () =>
              client.call('verifyPhoneOtpAndSignIn', data: any(named: 'data')),
        ).thenAnswer((_) async => {'customToken': 'tok'});
        when(
          () => auth.signInWithCustomToken('tok'),
        ).thenAnswer((_) async => _MockCredential());
        final (c, _) = await buildWith(null);
        final result = await c
            .read(authNotifierProvider.notifier)
            .phoneSignInWithOtp('+33600000000', '123456');
        expect(result.signedIn, isTrue);
        verify(() => auth.signInWithCustomToken('tok')).called(1);
      },
    );

    test('phoneSignInWithOtp throws StateError when token missing', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignIn', data: any(named: 'data')),
      ).thenAnswer((_) async => {});
      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .phoneSignInWithOtp('+33600000000', '123456'),
        throwsA(isA<StateError>()),
      );
    });

    test('phoneSignInWithOtp maps permission-denied to InvalidOtp', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignIn', data: any(named: 'data')),
      ).thenThrow(
        FirebaseFunctionsException(code: 'permission-denied', message: 'no'),
      );
      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .phoneSignInWithOtp('+33600000000', '000000'),
        throwsA(isA<InvalidOtpException>()),
      );
    });

    test('phoneSignInWithOtp rethrows other CF errors', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignIn', data: any(named: 'data')),
      ).thenThrow(
        FirebaseFunctionsException(code: 'unavailable', message: 'down'),
      );
      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .phoneSignInWithOtp('+33600000000', '000000'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('phoneSignUpWithOtp signs in with returned token', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignUp', data: any(named: 'data')),
      ).thenAnswer((_) async => {'customToken': 'tok'});
      when(
        () => auth.signInWithCustomToken('tok'),
      ).thenAnswer((_) async => _MockCredential());
      final (c, _) = await buildWith(null);
      await c
          .read(authNotifierProvider.notifier)
          .phoneSignUpWithOtp(
            phoneE164: '+33600000000',
            code: '123456',
            displayName: 'Alice',
            country: 'FR',
            termsVersion: '2026-06-07',
          );
      final captured =
          verify(
                () => client.call(
                  'verifyPhoneOtpAndSignUp',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map;
      expect(captured['termsVersion'], '2026-06-07');
      verify(() => auth.signInWithCustomToken('tok')).called(1);
    });

    test('phoneSignUpWithOtp throws StateError when token missing', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignUp', data: any(named: 'data')),
      ).thenAnswer((_) async => {});
      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .phoneSignUpWithOtp(
              phoneE164: '+33600000000',
              code: '123456',
              displayName: 'Alice',
              country: 'FR',
              termsVersion: '2026-06-07',
            ),
        throwsA(isA<StateError>()),
      );
    });

    test('phoneSignUpWithOtp maps already-exists to PhoneTaken', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignUp', data: any(named: 'data')),
      ).thenThrow(
        FirebaseFunctionsException(code: 'already-exists', message: 'taken'),
      );
      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .phoneSignUpWithOtp(
              phoneE164: '+33600000000',
              code: '123456',
              displayName: 'Alice',
              country: 'FR',
              termsVersion: '2026-06-07',
            ),
        throwsA(isA<PhoneTakenException>()),
      );
    });

    test('phoneSignUpWithOtp maps permission-denied to InvalidOtp', () async {
      when(
        () => client.call('verifyPhoneOtpAndSignUp', data: any(named: 'data')),
      ).thenThrow(
        FirebaseFunctionsException(code: 'permission-denied', message: 'no'),
      );
      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .phoneSignUpWithOtp(
              phoneE164: '+33600000000',
              code: '000000',
              displayName: 'Alice',
              country: 'FR',
              termsVersion: '2026-06-07',
            ),
        throwsA(isA<InvalidOtpException>()),
      );
    });

    // ---- email sign-up (consent fail-closed = M1, server version = M2) ---

    test('signUpWithEmailPassword finalizes consent via the CF', () async {
      final fbUser = makeFirebaseUser();
      final cred = _MockCredential();
      when(() => cred.user).thenReturn(fbUser);
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => cred);
      when(() => repo.getById('uid_1')).thenAnswer((_) async => null);

      final (c, _) = await buildWith(null);
      await c
          .read(authNotifierProvider.notifier)
          .signUpWithEmailPassword(
            displayName: 'Alice',
            email: 'alice@test.com',
            password: 'secret123',
          );

      verify(
        () => client.call('finalizeEmailSignUp', data: any(named: 'data')),
      ).called(1);
      verify(() => fbUser.sendEmailVerification(any())).called(1);
      verifyNever(() => fbUser.delete());
    });

    test('signUpWithEmailPassword rolls back and rethrows when consent write '
        'fails (fail-closed, M1)', () async {
      final fbUser = makeFirebaseUser();
      final cred = _MockCredential();
      when(() => cred.user).thenReturn(fbUser);
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => cred);
      when(() => repo.getById('uid_1')).thenAnswer((_) async => null);
      when(
        () => client.call('finalizeEmailSignUp', data: any(named: 'data')),
      ).thenThrow(
        FirebaseFunctionsException(code: 'unavailable', message: 'offline'),
      );

      final (c, _) = await buildWith(null);
      await expectLater(
        c
            .read(authNotifierProvider.notifier)
            .signUpWithEmailPassword(
              displayName: 'Alice',
              email: 'alice@test.com',
              password: 'secret123',
            ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      verify(() => fbUser.delete()).called(1);
    });

    test(
      'signUpWithEmailPassword throws when credential has no user',
      () async {
        final cred = _MockCredential();
        when(() => cred.user).thenReturn(null);
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => cred);

        final (c, _) = await buildWith(null);
        await expectLater(
          c
              .read(authNotifierProvider.notifier)
              .signUpWithEmailPassword(
                displayName: 'Alice',
                email: 'alice@test.com',
                password: 'secret123',
              ),
          throwsA(isA<StateError>()),
        );
      },
    );

    // ---- email sign-in / verification ------------------------------------

    test('signInWithEmailPassword delegates to FirebaseAuth', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _MockCredential());
      final (c, _) = await buildWith(null);
      await c
          .read(authNotifierProvider.notifier)
          .signInWithEmailPassword(email: 'a@b.c', password: 'pw');
      verify(
        () => auth.signInWithEmailAndPassword(email: 'a@b.c', password: 'pw'),
      ).called(1);
    });

    test('resendVerificationEmail is a no-op without a current user', () async {
      when(() => auth.currentUser).thenReturn(null);
      final (c, _) = await buildWith(null);
      await c.read(authNotifierProvider.notifier).resendVerificationEmail();
      // no throw
    });

    test('resendVerificationEmail sends when a user is present', () async {
      final fbUser = makeFirebaseUser();
      when(() => auth.currentUser).thenReturn(fbUser);
      final (c, _) = await buildWith(null);
      await c.read(authNotifierProvider.notifier).resendVerificationEmail();
      verify(() => fbUser.sendEmailVerification(any())).called(1);
    });

    test('completeEmailVerification applies the code and refreshes', () async {
      final fbUser = makeFirebaseUser();
      when(() => auth.applyActionCode('oob')).thenAnswer((_) async {});
      when(() => auth.currentUser).thenReturn(fbUser);
      when(
        () => repo.getById('uid_1'),
      ).thenAnswer((_) async => _makeUser(id: 'uid_1'));
      final (c, _) = await buildWith(null);
      final ok = await c
          .read(authNotifierProvider.notifier)
          .completeEmailVerification('oob');
      expect(ok, isTrue);
    });

    test('completeEmailVerification returns false on failure', () async {
      when(() => auth.applyActionCode('bad')).thenThrow(Exception('invalid'));
      final (c, _) = await buildWith(null);
      final ok = await c
          .read(authNotifierProvider.notifier)
          .completeEmailVerification('bad');
      expect(ok, isFalse);
    });
  });
}
