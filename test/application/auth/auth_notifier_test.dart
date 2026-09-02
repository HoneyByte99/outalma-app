// Tests AuthNotifier business logic (switchMode, updateProfile) using a
// test double that bypasses Firebase Auth.
//
// Pattern: _TestAuthNotifier overrides build() to return a pre-set
// authenticated state, so tests can exercise mutating methods without
// needing a real FirebaseAuth stream.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/repositories/user_repository.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockUserRepository extends Mock implements UserRepository {}

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
  String? photoPath,
  String? avatarId,
  String? pushToken,
  Gender? gender,
  DateTime? termsAcceptedAt,
}) {
  return AppUser(
    id: id,
    displayName: displayName,
    email: 'alice@test.com',
    country: 'FR',
    activeMode: activeMode,
    phoneE164: phoneE164,
    createdAt: DateTime(2024, 1, 1).toUtc(),
    photoPath: photoPath,
    avatarId: avatarId,
    pushToken: pushToken,
    gender: gender,
    termsAcceptedAt: termsAcceptedAt,
  );
}

ProviderContainer _makeAuthenticatedContainer(
  AppUser user,
  _MockUserRepository mockRepo,
) {
  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _AuthenticatedNotifier(user)),
      userRepositoryProvider.overrideWithValue(mockRepo),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockUserRepository mockRepo;

  setUp(() {
    mockRepo = _MockUserRepository();
    registerFallbackValue(_makeUser());
  });

  // -------------------------------------------------------------------------
  // switchMode
  // -------------------------------------------------------------------------

  group('AuthNotifier.switchMode', () {
    test('updates state to provider mode optimistically', () async {
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      final container = _makeAuthenticatedContainer(_makeUser(), mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .switchMode(ActiveMode.provider);

      final state = container.read(authNotifierProvider).valueOrNull;
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.activeMode, ActiveMode.provider);
    });

    test('calls userRepository.upsert with the updated user', () async {
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      final container = _makeAuthenticatedContainer(_makeUser(), mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .switchMode(ActiveMode.provider);

      final captured = verify(() => mockRepo.upsert(captureAny())).captured;
      final updatedUser = captured.first as AppUser;
      expect(updatedUser.id, 'user_1');
      expect(updatedUser.activeMode, ActiveMode.provider);
    });

    test('reverts state when repo.upsert throws', () async {
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Network error'));
      final container = _makeAuthenticatedContainer(_makeUser(), mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);

      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .switchMode(ActiveMode.provider),
        throwsA(isA<Exception>()),
      );

      final state = container.read(authNotifierProvider).valueOrNull;
      expect(
        (state as AuthAuthenticated).user.activeMode,
        ActiveMode.client,
        reason: 'State must be reverted after failure',
      );
    });

    test('does nothing when not authenticated', () async {
      final unauthContainer = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _UnauthenticatedNotifier()),
          userRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(unauthContainer.dispose);

      await unauthContainer.read(authNotifierProvider.future);
      await unauthContainer
          .read(authNotifierProvider.notifier)
          .switchMode(ActiveMode.provider);

      verifyNever(() => mockRepo.upsert(any()));
    });
  });

  // -------------------------------------------------------------------------
  // updateProfile
  // -------------------------------------------------------------------------

  group('AuthNotifier.updateProfile', () {
    test('updates displayName in state and calls upsert', () async {
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      final container = _makeAuthenticatedContainer(_makeUser(), mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(displayName: 'Bob');

      final state = container.read(authNotifierProvider).valueOrNull;
      expect((state as AuthAuthenticated).user.displayName, 'Bob');
      verify(() => mockRepo.upsert(any())).called(1);
    });

    test('updates country in state', () async {
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      final container = _makeAuthenticatedContainer(_makeUser(), mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(displayName: 'Alice', country: 'SN');

      final state = container.read(authNotifierProvider).valueOrNull;
      expect((state as AuthAuthenticated).user.country, 'SN');
    });

    test(
      'updateProfile keeps phoneE164 unchanged (phone is read-only)',
      () async {
        when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
        final container = _makeAuthenticatedContainer(
          _makeUser(phoneE164: '+33600000000'),
          mockRepo,
        );
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.future);
        await container
            .read(authNotifierProvider.notifier)
            .updateProfile(displayName: 'Alice', country: 'SN');

        final state = container.read(authNotifierProvider).valueOrNull;
        expect(
          (state as AuthAuthenticated).user.phoneE164,
          '+33600000000',
          reason: 'phone must not be mutated by updateProfile',
        );
      },
    );

    test('reverts state on repo.upsert failure', () async {
      when(() => mockRepo.upsert(any())).thenThrow(Exception('Write failed'));
      final container = _makeAuthenticatedContainer(_makeUser(), mockRepo);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);

      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .updateProfile(displayName: 'Bob'),
        throwsA(isA<Exception>()),
      );

      final state = container.read(authNotifierProvider).valueOrNull;
      expect(
        (state as AuthAuthenticated).user.displayName,
        'Alice',
        reason: 'State must be reverted to original on failure',
      );
    });
  });

  // -------------------------------------------------------------------------
  // setProfileImage: a photo, an illustrated avatar, or neither. Mutually
  // exclusive, which is the whole reason one method writes both fields.
  // -------------------------------------------------------------------------
  group('setProfileImage', () {
    late _MockUserRepository repo;

    setUp(() {
      repo = _MockUserRepository();
      when(
        () => repo.setProfileImage(
          userId: any(named: 'userId'),
          photoPath: any(named: 'photoPath'),
          avatarId: any(named: 'avatarId'),
        ),
      ).thenAnswer((_) async {});
    });

    test('choosing an avatar CLEARS a photo already on file', () async {
      // The regression test for the defect the plan review found: without
      // clearing photoPath, the display order (photo, then avatar) means the
      // sheet would close and nothing on screen would change.
      final user = _makeUser(photoPath: 'https://example.test/a.jpg');
      final container = _makeAuthenticatedContainer(user, repo);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .setProfileImage(avatarId: 'human_afro1_t2');

      final state =
          container.read(authNotifierProvider).value! as AuthAuthenticated;
      expect(state.user.avatarId, 'human_afro1_t2');
      expect(state.user.photoPath, isNull);
      verify(
        () => repo.setProfileImage(
          userId: 'user_1',
          photoPath: null,
          avatarId: 'human_afro1_t2',
        ),
      ).called(1);
    });

    test('importing a photo CLEARS the avatar', () async {
      final user = _makeUser(avatarId: 'human_afro1_t2');
      final container = _makeAuthenticatedContainer(user, repo);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .setProfileImage(photoPath: 'https://example.test/a.jpg');

      final state =
          container.read(authNotifierProvider).value! as AuthAuthenticated;
      expect(state.user.photoPath, 'https://example.test/a.jpg');
      expect(state.user.avatarId, isNull);
    });

    test('choosing neither returns the user to their initials', () async {
      final user = _makeUser(
        photoPath: 'https://example.test/a.jpg',
        avatarId: 'animal_blob1',
      );
      final container = _makeAuthenticatedContainer(user, repo);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container.read(authNotifierProvider.notifier).setProfileImage();

      final state =
          container.read(authNotifierProvider).value! as AuthAuthenticated;
      expect(state.user.photoPath, isNull);
      expect(state.user.avatarId, isNull);
      verify(
        () => repo.setProfileImage(
          userId: 'user_1',
          photoPath: null,
          avatarId: null,
        ),
      ).called(1);
    });

    test('it carries EVERY other field across', () async {
      // The user is rebuilt through the full constructor because copyWith
      // cannot express an erasure, and the compiler only protects the six
      // required parameters. Dropping phoneE164 here would blank the phone
      // number on the profile page until the next restart.
      final user = _makeUser(
        phoneE164: '+221770000000',
        pushToken: 'tok',
        gender: Gender.female,
        termsAcceptedAt: DateTime(2024, 2, 2).toUtc(),
        activeMode: ActiveMode.provider,
      );
      final container = _makeAuthenticatedContainer(user, repo);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .setProfileImage(avatarId: 'animal_blob1');

      final after =
          (container.read(authNotifierProvider).value! as AuthAuthenticated)
              .user;
      expect(after.phoneE164, '+221770000000');
      expect(after.pushToken, 'tok');
      expect(after.gender, Gender.female);
      expect(after.termsAcceptedAt, DateTime(2024, 2, 2).toUtc());
      expect(after.activeMode, ActiveMode.provider);
      expect(after.displayName, 'Alice');
      expect(after.email, 'alice@test.com');
      expect(after.country, 'FR');
      expect(after.createdAt, DateTime(2024, 1, 1).toUtc());
      expect(after.id, 'user_1');
    });

    test('a failed write rolls the state back and rethrows', () async {
      final failing = _MockUserRepository();
      when(
        () => failing.setProfileImage(
          userId: any(named: 'userId'),
          photoPath: any(named: 'photoPath'),
          avatarId: any(named: 'avatarId'),
        ),
      ).thenThrow(Exception('offline'));

      final user = _makeUser(avatarId: 'human_afro1_t2');
      final container = _makeAuthenticatedContainer(user, failing);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .setProfileImage(avatarId: 'animal_blob1'),
        throwsA(isA<Exception>()),
      );

      final after =
          (container.read(authNotifierProvider).value! as AuthAuthenticated)
              .user;
      expect(after.avatarId, 'human_afro1_t2', reason: 'state must roll back');
    });

    test('it does nothing when nobody is signed in', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_UnauthenticatedNotifier.new),
          userRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .setProfileImage(avatarId: 'human_afro1_t2');

      verifyNever(
        () => repo.setProfileImage(
          userId: any(named: 'userId'),
          photoPath: any(named: 'photoPath'),
          avatarId: any(named: 'avatarId'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // The avatar must survive the two methods that rebuild the user.
  // -------------------------------------------------------------------------
  group('the avatar survives', () {
    test('switchMode', () async {
      final repo = _MockUserRepository();
      when(() => repo.upsert(any())).thenAnswer((_) async {});
      final user = _makeUser(avatarId: 'human_afro1_t2');
      final container = _makeAuthenticatedContainer(user, repo);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .switchMode(ActiveMode.provider);

      final captured =
          verify(() => repo.upsert(captureAny())).captured.single as AppUser;
      expect(captured.activeMode, ActiveMode.provider);
      expect(captured.avatarId, 'human_afro1_t2');
    });

    test('updateProfile', () async {
      final repo = _MockUserRepository();
      when(() => repo.upsert(any())).thenAnswer((_) async {});
      final user = _makeUser(avatarId: 'human_afro1_t2');
      final container = _makeAuthenticatedContainer(user, repo);
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);

      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(displayName: 'Alice B.');

      final captured =
          verify(() => repo.upsert(captureAny())).captured.single as AppUser;
      expect(captured.displayName, 'Alice B.');
      expect(captured.avatarId, 'human_afro1_t2');
    });
  });
}
