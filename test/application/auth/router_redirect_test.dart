import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

// Tests the redirect logic extracted from RouterNotifier as a pure function.
// The full GoRouter integration is covered by widget tests; these unit tests
// protect the redirect decision rules.

String? _redirect(AuthState authState, String location) {
  const authRoutes = [AppRoutes.signIn, AppRoutes.signUp];
  final isAuthRoute = authRoutes.contains(location);

  return switch (authState) {
    AuthLoading() => null,
    // Guests may browse the public allowlist (delegates to the real helper so
    // this double cannot drift from RouterNotifier); everything else -> sign-in.
    AuthUnauthenticated() =>
      isAuthRoute || RouterNotifier.isGuestAllowed(location)
          ? null
          : AppRoutes.signIn,
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

  group('Router redirect - unauthenticated (guest)', () {
    test('allows /home for guest browsing', () {
      expect(_redirect(const AuthUnauthenticated(), AppRoutes.home), isNull);
    });

    test('allows a public service detail for a guest', () {
      expect(
        _redirect(const AuthUnauthenticated(), AppRoutes.serviceDetail('s1')),
        isNull,
      );
    });

    test('redirects a protected route (/bookings) to /sign-in', () {
      expect(
        _redirect(const AuthUnauthenticated(), AppRoutes.bookings),
        equals(AppRoutes.signIn),
      );
    });

    test('allows /sign-in to pass through', () {
      expect(_redirect(const AuthUnauthenticated(), AppRoutes.signIn), isNull);
    });

    test('allows /sign-up to pass through', () {
      expect(_redirect(const AuthUnauthenticated(), AppRoutes.signUp), isNull);
    });
  });

  group('Router redirect - authenticated', () {
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
  });

  group('Router redirect - loading', () {
    test('returns null (stay on current location) while loading', () {
      expect(_redirect(const AuthLoading(), AppRoutes.home), isNull);
      expect(_redirect(const AuthLoading(), AppRoutes.signIn), isNull);
    });
  });
}
