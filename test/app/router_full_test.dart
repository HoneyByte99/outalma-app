// Extended router redirect tests - P2.4 app layer coverage.
//
// Complements router_redirect_test.dart and router_redirect_extended_test.dart.
// Uses the same pure-function test-double pattern (no GoRouter / Firebase
// needed) to cover additional cases from RouterNotifier.redirect:
//
//   1. Provider-only routes in client mode → /home.
//   2. Unauthenticated user accessing any protected route → /sign-in.
//   3. Unknown / 404-like paths → no redirect (GoRouter renders its own 404).
//   4. AuthLoading state → no redirect for any location.
//   5. Auth-error state → /sign-in.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

// ---------------------------------------------------------------------------
// Test double - mirrors RouterNotifier.redirect as a pure function
// ---------------------------------------------------------------------------

/// Mirrors the complete redirect logic in RouterNotifier.redirect.
///
/// [authAsync]  - the current auth state (wraps AsyncValue semantics manually)
/// [mode]       - the active mode to use when [authAsync] is authenticated
/// [loc]        - the matched router location being evaluated
String? _redirect({
  required _AuthScenario authAsync,
  ActiveMode mode = ActiveMode.client,
  required String loc,
}) {
  switch (authAsync) {
    case _AuthScenario.loading:
      return null;
    case _AuthScenario.error:
      return AppRoutes.signIn;
    case _AuthScenario.unauthenticated:
      final isAuthRoute = loc == AppRoutes.signIn || loc == AppRoutes.signUp;
      return isAuthRoute ? null : AppRoutes.signIn;
    case _AuthScenario.authenticated:
      final isAuthRoute = loc == AppRoutes.signIn || loc == AppRoutes.signUp;
      if (isAuthRoute) return AppRoutes.home;

      final isClientTab =
          loc == AppRoutes.home ||
          loc == AppRoutes.bookings ||
          loc.startsWith('${AppRoutes.bookings}/');

      final isProviderTab =
          loc == AppRoutes.providerHome ||
          loc == AppRoutes.providerInbox ||
          loc.startsWith('${AppRoutes.providerInbox}/');

      final isSharedTab =
          loc == AppRoutes.chatsList || loc == AppRoutes.profile;

      if (!isSharedTab && mode == ActiveMode.provider && isClientTab) {
        return AppRoutes.providerHome;
      }
      if (!isSharedTab && mode == ActiveMode.client && isProviderTab) {
        return AppRoutes.home;
      }

      final isProviderOnlyRoute =
          loc.startsWith('/provider/onboarding') ||
          loc.startsWith('/provider/calendar') ||
          loc.startsWith('/provider/services');

      if (mode == ActiveMode.client && isProviderOnlyRoute) {
        return AppRoutes.home;
      }

      return null;
  }
}

enum _AuthScenario { loading, error, unauthenticated, authenticated }

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppUser _makeUser({ActiveMode activeMode = ActiveMode.client}) => AppUser(
  id: 'uid-router-full',
  displayName: 'Router Test User',
  email: 'router@example.com',
  country: 'FR',
  activeMode: activeMode,
  createdAt: DateTime(2024).toUtc(),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Provider-only routes accessed in client mode → /home
  // -------------------------------------------------------------------------

  group('client mode + provider-only routes → /home', () {
    const clientMode = ActiveMode.client;

    test('/provider/onboarding → /home', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.authenticated,
          mode: clientMode,
          loc: AppRoutes.providerOnboarding,
        ),
        equals(AppRoutes.home),
      );
    });

    test('/provider/calendar → /home', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.authenticated,
          mode: clientMode,
          loc: AppRoutes.providerCalendar,
        ),
        equals(AppRoutes.home),
      );
    });

    test('/provider/services/new → /home', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.authenticated,
          mode: clientMode,
          loc: AppRoutes.serviceNew,
        ),
        equals(AppRoutes.home),
      );
    });

    test('/provider/services/:id/edit → /home', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.authenticated,
          mode: clientMode,
          loc: AppRoutes.serviceEdit('svc-abc'),
        ),
        equals(AppRoutes.home),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. Unauthenticated user accessing protected routes → /sign-in
  // -------------------------------------------------------------------------

  group('unauthenticated user + protected routes → /sign-in', () {
    test('/home → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.home,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('/bookings → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.bookings,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('/provider → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.providerHome,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('/provider/inbox → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.providerInbox,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('/profile → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.profile,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('/notifications → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.notifications,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('/chats → /sign-in', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.chatsList,
        ),
        equals(AppRoutes.signIn),
      );
    });

    test('unauthenticated user may visit /sign-in without redirect', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.signIn,
        ),
        isNull,
      );
    });

    test('unauthenticated user may visit /sign-up without redirect', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: AppRoutes.signUp,
        ),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. Unknown / 404-like paths - no redirect
  //    GoRouter handles unknown routes itself; RouterNotifier returns null.
  // -------------------------------------------------------------------------

  group('unknown paths → no redirect (GoRouter handles 404)', () {
    test('/unknown-route → null (authenticated)', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.authenticated,
          mode: ActiveMode.client,
          loc: '/unknown-route',
        ),
        isNull,
      );
    });

    test('/totally/made/up → null (authenticated)', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.authenticated,
          mode: ActiveMode.client,
          loc: '/totally/made/up',
        ),
        isNull,
      );
    });

    test('/unknown-route → /sign-in (unauthenticated)', () {
      expect(
        _redirect(
          authAsync: _AuthScenario.unauthenticated,
          loc: '/unknown-route',
        ),
        equals(AppRoutes.signIn),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 4. AuthLoading → always null (stay put)
  // -------------------------------------------------------------------------

  group('AuthLoading → null for all locations', () {
    for (final loc in [
      AppRoutes.home,
      AppRoutes.signIn,
      AppRoutes.signUp,
      AppRoutes.providerHome,
      AppRoutes.bookings,
      '/some/unknown',
    ]) {
      test('loading at $loc → null', () {
        expect(_redirect(authAsync: _AuthScenario.loading, loc: loc), isNull);
      });
    }
  });

  // -------------------------------------------------------------------------
  // 5. Auth error state → /sign-in
  // -------------------------------------------------------------------------

  group('auth error → /sign-in', () {
    test('/home during auth error → /sign-in', () {
      expect(
        _redirect(authAsync: _AuthScenario.error, loc: AppRoutes.home),
        equals(AppRoutes.signIn),
      );
    });

    test(
      '/sign-in during auth error still goes to /sign-in (same location)',
      () {
        expect(
          _redirect(authAsync: _AuthScenario.error, loc: AppRoutes.signIn),
          equals(AppRoutes.signIn),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // 6. Authenticated in provider mode - provider-only routes are allowed
  // -------------------------------------------------------------------------

  group(
    'authenticated + provider mode + provider-only routes → no redirect',
    () {
      const providerMode = ActiveMode.provider;

      test('/provider/onboarding → no redirect in provider mode', () {
        expect(
          _redirect(
            authAsync: _AuthScenario.authenticated,
            mode: providerMode,
            loc: AppRoutes.providerOnboarding,
          ),
          isNull,
        );
      });

      test('/provider/calendar → no redirect in provider mode', () {
        expect(
          _redirect(
            authAsync: _AuthScenario.authenticated,
            mode: providerMode,
            loc: AppRoutes.providerCalendar,
          ),
          isNull,
        );
      });

      test('/provider/services/new → no redirect in provider mode', () {
        expect(
          _redirect(
            authAsync: _AuthScenario.authenticated,
            mode: providerMode,
            loc: AppRoutes.serviceNew,
          ),
          isNull,
        );
      });
    },
  );

  // -------------------------------------------------------------------------
  // 7. AppUser and AuthState construction sanity (matches existing pattern)
  // -------------------------------------------------------------------------

  group('AuthState construction sanity', () {
    test('AuthAuthenticated holds user correctly', () {
      final user = _makeUser(activeMode: ActiveMode.provider);
      final state = AuthAuthenticated(user);
      expect(state.user.id, equals('uid-router-full'));
      expect(state.user.activeMode, equals(ActiveMode.provider));
    });

    test('AuthUnauthenticated is value-equal', () {
      expect(const AuthUnauthenticated(), equals(const AuthUnauthenticated()));
    });

    test('AuthLoading is value-equal', () {
      expect(const AuthLoading(), equals(const AuthLoading()));
    });
  });
}
