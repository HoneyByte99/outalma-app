import 'package:flutter_test/flutter_test.dart';
import 'package:outlama_app/src/application/auth/auth_state.dart';
import 'package:outlama_app/src/domain/enums/active_mode.dart';
import 'package:outlama_app/src/domain/models/app_user.dart';

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

    test('pattern matching exhausts all states without default branch', () {
      final states = <AuthState>[
        const AuthLoading(),
        const AuthUnauthenticated(),
        AuthAuthenticated(_testUser()),
      ];

      for (final s in states) {
        final label = switch (s) {
          AuthLoading() => 'loading',
          AuthUnauthenticated() => 'unauthenticated',
          AuthAuthenticated() => 'authenticated',
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
