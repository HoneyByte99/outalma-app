import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

void main() {
  group('AuthState sealed class', () {
    test('AuthLoading is an AuthState', () {
      const state = AuthLoading();
      expect(state, isA<AuthState>());
    });

    test('AuthUnauthenticated is an AuthState', () {
      const state = AuthUnauthenticated();
      expect(state, isA<AuthState>());
    });

    test('AuthAuthenticated carries AppUser', () {
      final user = _testUser();
      final state = AuthAuthenticated(user);
      expect(state, isA<AuthState>());
      expect(state.user.id, equals('uid-1'));
      expect(state.user.displayName, equals('Alice'));
      expect(state.user.activeMode, equals(ActiveMode.client));
    });

    test('AuthPhoneVerification carries verificationId and phoneNumber', () {
      const state = AuthPhoneVerification(
        verificationId: 'vid-123',
        phoneNumber: '+221701234567',
      );
      expect(state, isA<AuthState>());
      expect(state.verificationId, equals('vid-123'));
      expect(state.phoneNumber, equals('+221701234567'));
    });

    test('pattern matching exhausts all states without default branch', () {
      final states = <AuthState>[
        const AuthLoading(),
        const AuthUnauthenticated(),
        AuthAuthenticated(_testUser()),
        const AuthPhoneVerification(
          verificationId: 'vid',
          phoneNumber: '+221701234567',
        ),
      ];

      for (final s in states) {
        final label = switch (s) {
          AuthLoading() => 'loading',
          AuthUnauthenticated() => 'unauthenticated',
          AuthAuthenticated() => 'authenticated',
          AuthPhoneVerification() => 'phone-verification',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}

AppUser _testUser() => AppUser(
  id: 'uid-1',
  displayName: 'Alice',
  email: 'alice@example.com',
  country: 'FR',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024),
);
