// The AuthNotifier paths that reach a server: the two phone verifications, the
// account deletion, the data export, the email sign-up/sign-in and the email
// verification round trip.
//
// These were untestable until the callable transport moved behind
// `callableClientProvider`: `CallableFunctionClient` reads
// `FirebaseAuth.instance` before it sends anything, which throws in a test with
// no initialised Firebase app, so every one of these methods died on its first
// line. With the seam they are ordinary code.
//
// What they protect is not the plumbing but the translation: the two phone
// callables turn a `permission-denied` into `InvalidOtpException` and an
// `already-exists` into `PhoneTakenException`, and the screens branch on those
// two to say "wrong code" rather than "number already taken". Swap them and the
// user is told the wrong thing with a perfectly green suite.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/data/services/callable_function_client.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/repositories/user_repository.dart';

// ---------------------------------------------------------------------------
// Doubles
// ---------------------------------------------------------------------------

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _FakeActionCodeSettings extends Fake implements ActionCodeSettings {}

class _FakeAppUser extends Fake implements AppUser {}

/// Records every callable invocation and answers from a scripted table.
class _FakeCallableClient implements CallableFunctionClient {
  _FakeCallableClient({this.answers = const {}, this.errors = const {}});

  final Map<String, Map<String, dynamic>> answers;
  final Map<String, Object> errors;
  final calls = <({String name, Map<String, dynamic> data})>[];

  @override
  Future<Map<String, dynamic>> call(
    String name, {
    Map<String, dynamic> data = const {},
  }) async {
    calls.add((name: name, data: data));
    final error = errors[name];
    if (error != null) throw error;
    return answers[name] ?? const {};
  }
}

/// Bypasses the FirebaseAuth stream `build()` would subscribe to.
class _TestNotifier extends AuthNotifier {
  _TestNotifier([this._state = const AuthUnauthenticated()]);
  final AuthState _state;

  @override
  Future<AuthState> build() async => _state;
}

FirebaseFunctionsException _functionsError(String code) =>
    FirebaseFunctionsException(code: code, message: code);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActionCodeSettings());
    registerFallbackValue(_FakeAppUser());
  });

  late _MockFirebaseAuth auth;
  late _MockUserRepository repo;

  setUp(() {
    auth = _MockFirebaseAuth();
    repo = _MockUserRepository();
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => auth.currentUser).thenReturn(null);
    when(() => repo.upsert(any())).thenAnswer((_) async {});
    when(() => repo.getById(any())).thenAnswer((_) async => null);
  });

  ProviderContainer makeContainer({
    _FakeCallableClient? client,
    FakeFirebaseFirestore? firestore,
    AuthState state = const AuthUnauthenticated(),
  }) {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => _TestNotifier(state)),
        firebaseAuthProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(repo),
        firestoreProvider.overrideWithValue(
          firestore ?? FakeFirebaseFirestore(),
        ),
        if (client != null) callableClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<AuthNotifier> notifierOf(ProviderContainer c) async {
    await c.read(authNotifierProvider.future);
    return c.read(authNotifierProvider.notifier);
  }

  // -------------------------------------------------------------------------
  group('phoneSignInWithOtp', () {
    test('signs in with the custom token the server returned', () async {
      final client = _FakeCallableClient(
        answers: {
          'verifyPhoneOtpAndSignIn': {'newUser': false, 'customToken': 'tok-1'},
        },
      );
      when(
        () => auth.signInWithCustomToken(any()),
      ).thenAnswer((_) async => _MockUserCredential());
      final notifier = await notifierOf(makeContainer(client: client));

      final result = await notifier.phoneSignInWithOtp(
        '+221771234567',
        '123456',
      );

      expect(result.signedIn, isTrue);
      expect(result.isNewUser, isFalse);
      verify(() => auth.signInWithCustomToken('tok-1')).called(1);
      expect(client.calls.single.data, {
        'phone': '+221771234567',
        'code': '123456',
      });
    });

    test('an unknown number routes to sign-up WITHOUT signing anyone in', () {
      final client = _FakeCallableClient(
        answers: {
          'verifyPhoneOtpAndSignIn': {'newUser': true},
        },
      );

      return notifierOf(makeContainer(client: client)).then((notifier) async {
        final result = await notifier.phoneSignInWithOtp(
          '+221770000000',
          '123456',
        );

        expect(result.signedIn, isFalse);
        expect(result.isNewUser, isTrue);
        verifyNever(() => auth.signInWithCustomToken(any()));
      });
    });

    test(
      'a wrong code becomes InvalidOtpException, not a Firebase type',
      () async {
        // The screen catches exactly this to say "wrong code"; a raw
        // FirebaseFunctionsException would fall through to "an error occurred".
        final client = _FakeCallableClient(
          errors: {
            'verifyPhoneOtpAndSignIn': _functionsError('permission-denied'),
          },
        );
        final notifier = await notifierOf(makeContainer(client: client));

        await expectLater(
          () => notifier.phoneSignInWithOtp('+221771234567', '000000'),
          throwsA(isA<InvalidOtpException>()),
        );
      },
    );

    test('any other server code is rethrown as is, never mistaken for a '
        'wrong code', () async {
      final client = _FakeCallableClient(
        errors: {'verifyPhoneOtpAndSignIn': _functionsError('unavailable')},
      );
      final notifier = await notifierOf(makeContainer(client: client));

      await expectLater(
        () => notifier.phoneSignInWithOtp('+221771234567', '123456'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test(
      'a success with no token fails loudly instead of half signing in',
      () async {
        final client = _FakeCallableClient(
          answers: {
            'verifyPhoneOtpAndSignIn': {'newUser': false},
          },
        );
        final notifier = await notifierOf(makeContainer(client: client));

        await expectLater(
          () => notifier.phoneSignInWithOtp('+221771234567', '123456'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  group('phoneSignUpWithOtp', () {
    Future<void> signUp(AuthNotifier n) => n.phoneSignUpWithOtp(
      phoneE164: '+221771234567',
      code: '123456',
      displayName: 'Awa Cisse',
      country: 'SN',
      gender: Gender.female,
    );

    test(
      'carries the declared gender to the server, which writes the doc',
      () async {
        // There is no client write afterwards on this path, so a gender dropped
        // here is a gender lost for good.
        final client = _FakeCallableClient(
          answers: {
            'verifyPhoneOtpAndSignUp': {'customToken': 'tok-2'},
          },
        );
        when(
          () => auth.signInWithCustomToken(any()),
        ).thenAnswer((_) async => _MockUserCredential());
        final notifier = await notifierOf(makeContainer(client: client));

        await signUp(notifier);

        expect(client.calls.single.data['gender'], 'female');
        expect(client.calls.single.data['displayName'], 'Awa Cisse');
        expect(client.calls.single.data['country'], 'SN');
        verify(() => auth.signInWithCustomToken('tok-2')).called(1);
      },
    );

    test(
      'a taken number becomes PhoneTakenException, not "wrong code"',
      () async {
        final client = _FakeCallableClient(
          errors: {
            'verifyPhoneOtpAndSignUp': _functionsError('already-exists'),
          },
        );
        final notifier = await notifierOf(makeContainer(client: client));

        await expectLater(
          signUp(notifier),
          throwsA(isA<PhoneTakenException>()),
        );
      },
    );

    test(
      'a wrong code becomes InvalidOtpException, not "number taken"',
      () async {
        final client = _FakeCallableClient(
          errors: {
            'verifyPhoneOtpAndSignUp': _functionsError('permission-denied'),
          },
        );
        final notifier = await notifierOf(makeContainer(client: client));

        await expectLater(
          signUp(notifier),
          throwsA(isA<InvalidOtpException>()),
        );
      },
    );

    test('any other server code is rethrown as is', () async {
      final client = _FakeCallableClient(
        errors: {'verifyPhoneOtpAndSignUp': _functionsError('internal')},
      );
      final notifier = await notifierOf(makeContainer(client: client));

      await expectLater(
        signUp(notifier),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test(
      'a success with no token fails loudly instead of half signing up',
      () async {
        final client = _FakeCallableClient(
          answers: {'verifyPhoneOtpAndSignUp': const {}},
        );
        final notifier = await notifierOf(makeContainer(client: client));

        await expectLater(signUp(notifier), throwsA(isA<StateError>()));
      },
    );
  });

  // -------------------------------------------------------------------------
  group('account deletion and export', () {
    test('deletion is server-authoritative, and signs out after', () async {
      // The order matters: signing out first would drop the ID token the
      // callable authenticates with, and the account would survive.
      final client = _FakeCallableClient();
      final notifier = await notifierOf(makeContainer(client: client));

      await notifier.deleteAccount();

      expect(client.calls.single.name, 'deleteMyAccount');
      verify(() => auth.signOut()).called(1);
    });

    test('a failed deletion does NOT sign the user out', () async {
      // Otherwise the user is left believing the account is gone while it is
      // not, with no session left to retry from.
      final client = _FakeCallableClient(
        errors: {'deleteMyAccount': _functionsError('internal')},
      );
      final notifier = await notifierOf(makeContainer(client: client));

      await expectLater(notifier.deleteAccount(), throwsA(isA<Exception>()));
      verifyNever(() => auth.signOut());
    });

    test('the export returns what the server sent, untouched', () async {
      final client = _FakeCallableClient(
        answers: {
          'exportMyData': {'user': 'x', 'bookings': []},
        },
      );
      final notifier = await notifierOf(makeContainer(client: client));

      expect(await notifier.exportMyData(), {'user': 'x', 'bookings': []});
    });
  });

  // -------------------------------------------------------------------------
  group('signOut', () {
    test('clears this device push token BEFORE signing out', () async {
      // Left behind, it keeps delivering the previous account's chat previews
      // to this lock screen.
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({
        'id': 'u1',
        'pushToken': 'token-abc',
      });
      final user = _MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => auth.currentUser).thenReturn(user);
      final notifier = await notifierOf(makeContainer(firestore: firestore));

      await notifier.signOut();

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!.containsKey('pushToken'), isFalse);
      verify(() => auth.signOut()).called(1);
    });

    test('signs out even when clearing the token fails', () async {
      // Best-effort by design: a user who wants out gets out, offline or not.
      // Blocking here would strand them in a session they asked to leave.
      final broken = _MockFirestore();
      when(
        () => broken.collection(any()),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));
      final user = _MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => auth.currentUser).thenReturn(user);
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_TestNotifier.new),
          firebaseAuthProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(repo),
          firestoreProvider.overrideWithValue(broken),
        ],
      );
      addTearDown(container.dispose);
      final notifier = await notifierOf(container);

      await notifier.signOut();

      verify(() => auth.signOut()).called(1);
    });

    test('signs out anyway when there is no session to clean up', () async {
      final notifier = await notifierOf(makeContainer());

      await notifier.signOut();

      verify(() => auth.signOut()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  group('email sign-up', () {
    Future<void> signUp(AuthNotifier n) => n.signUpWithEmailPassword(
      displayName: 'Awa Cisse',
      email: 'awa@example.com',
      password: 'motdepasse',
      gender: Gender.female,
    );

    _MockUser stubNewUser() {
      final user = _MockUser();
      final credential = _MockUserCredential();
      when(() => user.uid).thenReturn('u1');
      when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
      when(() => user.sendEmailVerification(any())).thenAnswer((_) async {});
      when(() => credential.user).thenReturn(user);
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);
      return user;
    }

    test(
      'writes the account doc with the consent and the declared gender',
      () async {
        stubNewUser();
        final notifier = await notifierOf(makeContainer());

        await signUp(notifier);

        final written =
            verify(() => repo.upsert(captureAny())).captured.single as AppUser;
        expect(written.displayName, 'Awa Cisse');
        expect(written.gender, Gender.female);
        expect(written.termsAcceptedAt, isNotNull);
      },
    );

    test(
      'preserves createdAt when the auth listener already wrote a doc',
      () async {
        // The Firestore rule refuses an update that moves createdAt, so losing
        // it here would make every later profile save fail.
        final earlier = DateTime.utc(2026, 1, 1);
        stubNewUser();
        when(() => repo.getById('u1')).thenAnswer(
          (_) async => AppUser(
            id: 'u1',
            displayName: '',
            email: 'awa@example.com',
            country: 'SN',
            activeMode: ActiveMode.provider,
            createdAt: earlier,
          ),
        );
        final notifier = await notifierOf(makeContainer());

        await signUp(notifier);

        final written =
            verify(() => repo.upsert(captureAny())).captured.single as AppUser;
        expect(written.createdAt, earlier);
        expect(written.country, 'SN');
        expect(written.activeMode, ActiveMode.provider);
      },
    );

    test(
      'a failed verification mail does NOT abort a completed sign-up',
      () async {
        // The user is already in; the screen offers a resend.
        final user = stubNewUser();
        when(
          () => user.sendEmailVerification(any()),
        ).thenThrow(FirebaseAuthException(code: 'too-many-requests'));
        final notifier = await notifierOf(makeContainer());

        await signUp(notifier);

        verify(() => repo.upsert(any())).called(1);
      },
    );

    test('a failed display name does NOT abort sign-up either', () async {
      final user = stubNewUser();
      when(
        () => user.updateDisplayName(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      final notifier = await notifierOf(makeContainer());

      await signUp(notifier);

      verify(() => repo.upsert(any())).called(1);
    });

    test(
      'a credential with no user fails loudly rather than writing junk',
      () async {
        final credential = _MockUserCredential();
        when(() => credential.user).thenReturn(null);
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        final notifier = await notifierOf(makeContainer());

        await expectLater(signUp(notifier), throwsA(isA<StateError>()));
        verifyNever(() => repo.upsert(any()));
      },
    );
  });

  // -------------------------------------------------------------------------
  group('email sign-in and verification', () {
    test('signs in with the credentials given', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _MockUserCredential());
      final notifier = await notifierOf(makeContainer());

      await notifier.signInWithEmailPassword(
        email: 'awa@example.com',
        password: 'motdepasse',
      );

      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'awa@example.com',
          password: 'motdepasse',
        ),
      ).called(1);
    });

    test('resending does nothing when nobody is signed in', () async {
      // A signed-out caller must return quietly, not throw on a null user.
      final absent = _MockUser();
      when(() => absent.sendEmailVerification(any())).thenAnswer((_) async {});
      final notifier = await notifierOf(makeContainer());

      await notifier.resendVerificationEmail();

      verifyNever(() => absent.sendEmailVerification(any()));
    });

    test('resending targets the signed-in user', () async {
      final user = _MockUser();
      when(() => user.sendEmailVerification(any())).thenAnswer((_) async {});
      when(() => auth.currentUser).thenReturn(user);
      final notifier = await notifierOf(makeContainer());

      await notifier.resendVerificationEmail();

      verify(() => user.sendEmailVerification(any())).called(1);
    });

    test('applying the link reloads the user and reports success', () async {
      final user = _MockUser();
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => user.uid).thenReturn('u1');
      when(() => user.displayName).thenReturn('Awa');
      when(() => user.email).thenReturn('awa@example.com');
      when(() => user.emailVerified).thenReturn(true);
      when(() => auth.currentUser).thenReturn(user);
      when(() => auth.applyActionCode(any())).thenAnswer((_) async {});
      final notifier = await notifierOf(makeContainer());

      expect(await notifier.completeEmailVerification('oob-code'), isTrue);
      verify(() => user.reload()).called(1);
    });

    test(
      'a stale or reused link reports failure instead of throwing',
      () async {
        // The deep-link handler runs on app start: an exception there would
        // take the whole launch down.
        when(
          () => auth.applyActionCode(any()),
        ).thenThrow(FirebaseAuthException(code: 'invalid-action-code'));
        final notifier = await notifierOf(makeContainer());

        expect(await notifier.completeEmailVerification('stale'), isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  group('the two exceptions the screens branch on', () {
    test('each names itself, so a crash report says which one fired', () {
      expect(PhoneTakenException().toString(), contains('PhoneTakenException'));
      expect(InvalidOtpException().toString(), contains('InvalidOtpException'));
    });
  });
}
