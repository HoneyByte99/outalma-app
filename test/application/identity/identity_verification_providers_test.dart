import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/identity/identity_verification_providers.dart';
import 'package:outalma_app/src/data/repositories/firestore_identity_verification_repository.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/identity_status.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

class _AuthedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthAuthenticated(
    AppUser(
      id: 'p1',
      displayName: 'Provider',
      email: 'p@test.com',
      country: 'SN',
      activeMode: ActiveMode.provider,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

class _AnonNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

void main() {
  test('the repository provider builds a Firestore-backed reader', () {
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(FakeFirebaseFirestore())],
    );
    addTearDown(container.dispose);
    expect(
      container.read(identityVerificationRepositoryProvider),
      isA<FirestoreIdentityVerificationRepository>(),
    );
  });

  test('streams the signed-in provider\'s latest file', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('identity_verifications').doc('v1').set({
      'providerId': 'p1',
      'status': 'approved',
      'attempt': 1,
      'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
      'reviewedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 21)),
    });
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        authNotifierProvider.overrideWith(_AuthedNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.future);
    final record = await container.read(myIdentityVerificationProvider.future);
    expect(record, isNotNull);
    expect(record!.status, IdentityStatus.approved);
  });

  test('emits nothing while unauthenticated (no uid to read)', () async {
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        authNotifierProvider.overrideWith(_AnonNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    // Keep the provider alive so it resolves.
    container.listen(myIdentityVerificationProvider, (_, __) {});

    await container.read(authNotifierProvider.future);
    await Future<void>.delayed(Duration.zero);
    // An empty stream never produces a value: the state stays loading rather
    // than reading a file for a user that is not there.
    expect(container.read(myIdentityVerificationProvider).isLoading, isTrue);
  });
}
