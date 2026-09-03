// firebaseAuthProvider/firestoreProvider/userRepositoryProvider are thin
// Firebase-backed wiring with nothing to unit-test beyond "does it
// construct", already covered by every widget test that boots the app
// through ProviderScope. notificationInitProvider's authenticated branch
// constructs a real FirebaseMessaging/Firestore-backed NotificationService
// (its own territory, not this file's); `flutter_test` never calls
// `Firebase.initializeApp`, so that construction throws before any network
// call, the same "real, unmocked, not a business exception" shape
// functions_identity_submit_service_test.dart relies on.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/data/services/log_session_service.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

class _FakeUnauthenticatedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

class _FakeAuthenticatedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'me',
      displayName: 'Me',
      email: 'me@test.com',
      country: 'FR',
      activeMode: ActiveMode.client,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

void main() {
  test('logSessionServiceProvider resolves to a LogSessionService', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(logSessionServiceProvider), isA<LogSessionService>());
  });

  test('notificationInitProvider does nothing when signed out, never touches '
      'FirebaseMessaging', () async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_FakeUnauthenticatedNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    // Primed first: notificationInitProvider watches authNotifierProvider,
    // and reading its .future while the watched provider is still on its own
    // first (loading) tick orphans the future when the watch fires the
    // rebuild, a Riverpod timing artifact of this test setup, not of the
    // provider under test.
    await container.read(authNotifierProvider.future);

    await expectLater(
      container.read(notificationInitProvider.future),
      completes,
    );
  });

  test('notificationInitProvider attempts setup when signed in', () async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthenticatedNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.future);

    // Reaches NotificationService construction (FirebaseMessaging.instance),
    // which throws with no Firebase app in this test environment: proof the
    // guard let the authenticated branch run, not a business outcome.
    await expectLater(
      container.read(notificationInitProvider.future),
      throwsA(anything),
    );
  });
}
