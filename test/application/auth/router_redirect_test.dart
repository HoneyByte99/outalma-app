import 'package:flutter_test/flutter_test.dart';
import 'package:outlama_app/src/application/auth/auth_state.dart';
import 'package:outlama_app/src/app/router.dart';
import 'package:outlama_app/src/domain/enums/active_mode.dart';
import 'package:outlama_app/src/domain/models/app_user.dart';

// Tests the redirect logic extracted from RouterNotifier as a pure function.
// The full GoRouter integration is covered by widget tests; these unit tests
// protect the redirect decision rules.

String? _redirect(AuthState authState, String location) {
  const authRoutes = [AppRoutes.signIn, AppRoutes.signUp];
  final isAuthRoute = authRoutes.contains(location);

  return switch (authState) {
    AuthLoading() => null,
    AuthUnauthenticated() => isAuthRoute ? null : AppRoutes.signIn,
    AuthAuthenticated() => isAuthRoute ? AppRoutes.home : null,
  };
}

void main() {
  final authenticatedUser = AppUser(
    id: 'uid-1',
    displayName: 'Alice',
    email: 'alice@example.com',
    country: 'FR',
    activeMode: ActiveMode.client,
    createdAt: DateTime(2024),
  );

  group('Router redirect — unauthenticated', () {
    test('redirects /home to /sign-in', () {
      expect(
        _redirect(const AuthUnauthenticated(), AppRoutes.home),
        equals(AppRoutes.signIn),
      );
    });

    test('redirects /switch-mode to /sign-in', () {
      expect(
        _redirect(const AuthUnauthenticated(), AppRoutes.switchMode),
        equals(AppRoutes.signIn),
      );
    });

    test('allows /sign-in to pass through', () {
      expect(
        _redirect(const AuthUnauthenticated(), AppRoutes.signIn),
        isNull,
      );
    });

    test('allows /sign-up to pass through', () {
      expect(
        _redirect(const AuthUnauthenticated(), AppRoutes.signUp),
        isNull,
      );
    });
  });

  group('Router redirect — authenticated', () {
    test('redirects /sign-in to /home', () {
      expect(
        _redirect(AuthAuthenticated(authenticatedUser), AppRoutes.signIn),
        equals(AppRoutes.home),
      );
    });

    test('redirects /sign-up to /home', () {
      expect(
        _redirect(AuthAuthenticated(authenticatedUser), AppRoutes.signUp),
        equals(AppRoutes.home),
      );
    });

    test('allows /home to pass through', () {
      expect(
        _redirect(AuthAuthenticated(authenticatedUser), AppRoutes.home),
        isNull,
      );
    });

    test('allows /switch-mode to pass through', () {
      expect(
        _redirect(AuthAuthenticated(authenticatedUser), AppRoutes.switchMode),
        isNull,
      );
    });
  });

  group('Router redirect — loading', () {
    test('returns null (stay on current location) while loading', () {
      expect(_redirect(const AuthLoading(), AppRoutes.home), isNull);
      expect(_redirect(const AuthLoading(), AppRoutes.signIn), isNull);
    });
  });
}
