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

    test('does not call isPhoneTaken when phone is not changing', () async {
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});
      // user has no phone; updateProfile called without phone → no check needed
      final container = _makeAuthenticatedContainer(
        _makeUser(phoneE164: null),
        mockRepo,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(displayName: 'Alice');

      verifyNever(
        () =>
            mockRepo.isPhoneTaken(any(), excludeUid: any(named: 'excludeUid')),
      );
    });

    test('calls isPhoneTaken when phone changes', () async {
      when(
        () =>
            mockRepo.isPhoneTaken(any(), excludeUid: any(named: 'excludeUid')),
      ).thenAnswer((_) async => false);
      when(() => mockRepo.upsert(any())).thenAnswer((_) async {});

      final container = _makeAuthenticatedContainer(
        _makeUser(phoneE164: '+33600000000'),
        mockRepo,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(
            displayName: 'Alice',
            phoneE164: '+33611111111', // different phone
          );

      verify(
        () => mockRepo.isPhoneTaken(
          '+33611111111',
          excludeUid: any(named: 'excludeUid'),
        ),
      ).called(1);
    });

    test('throws PhoneTakenException when new phone already in use', () async {
      when(
        () =>
            mockRepo.isPhoneTaken(any(), excludeUid: any(named: 'excludeUid')),
      ).thenAnswer((_) async => true);

      final container = _makeAuthenticatedContainer(
        _makeUser(phoneE164: '+33600000000'),
        mockRepo,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);

      await expectLater(
        container
            .read(authNotifierProvider.notifier)
            .updateProfile(displayName: 'Alice', phoneE164: '+33699999999'),
        throwsA(isA<PhoneTakenException>()),
      );
    });

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
}
