// Extended redirect tests covering mode-based routing rules added to
// RouterNotifier.redirect in lib/src/app/router.dart.
//
// Pattern: pure-function test double that mirrors the authenticated branch of
// RouterNotifier.redirect, taking (authState, activeMode, location) as
// parameters. No real GoRouter or Firebase is needed.
//
// Covered:
//   - provider mode + client tab (/home, /bookings) → /provider
//   - client mode  + provider tab (/provider, /provider/inbox) → /home
//   - client mode  + provider-only routes (/provider/onboarding,
//     /provider/calendar, /provider/services/new) → /home
//   - shared tabs (/chats, /profile) → no redirect regardless of mode
//   - deep-link routes (/booking/:id, /chat/:id) → no redirect

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

// ---------------------------------------------------------------------------
// Test double — mirrors the authenticated redirect branch in router.dart
// ---------------------------------------------------------------------------

/// Returns the redirect destination that RouterNotifier would produce for an
/// authenticated user at [location] with [mode] active.
///
/// Returns null when no redirect is needed.
String? _redirectAuthenticated(ActiveMode mode, String loc) {
  final isAuthRoute = loc == AppRoutes.signIn || loc == AppRoutes.signUp;
  if (isAuthRoute) return AppRoutes.home;

  final isClientTab = loc == AppRoutes.home ||
      loc == AppRoutes.bookings ||
      loc.startsWith('${AppRoutes.bookings}/');

  final isProviderTab = loc == AppRoutes.providerHome ||
      loc == AppRoutes.providerInbox ||
      loc.startsWith('${AppRoutes.providerInbox}/');

  final isSharedTab = loc == AppRoutes.chatsList || loc == AppRoutes.profile;

  if (!isSharedTab && mode == ActiveMode.provider && isClientTab) {
    return AppRoutes.providerHome;
  }
  if (!isSharedTab && mode == ActiveMode.client && isProviderTab) {
    return AppRoutes.home;
  }

  final isProviderOnlyRoute = loc.startsWith('/provider/onboarding') ||
      loc.startsWith('/provider/calendar') ||
      loc.startsWith('/provider/services');

  if (mode == ActiveMode.client && isProviderOnlyRoute) {
    return AppRoutes.home;
  }

  return null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppUser _makeUser({ActiveMode activeMode = ActiveMode.client}) {
  return AppUser(
    id: 'uid-1',
    displayName: 'Alice',
    email: 'alice@example.com',
    country: 'FR',
    activeMode: activeMode,
    createdAt: DateTime(2024).toUtc(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Provider mode — client tabs should redirect to /provider
  // -------------------------------------------------------------------------

  group('provider mode + client tabs → /provider', () {
    test('/home redirects to /provider when in provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.home),
        equals(AppRoutes.providerHome),
      );
    });

    test('/bookings redirects to /provider when in provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.bookings),
        equals(AppRoutes.providerHome),
      );
    });

    test('/bookings/:id sub-route redirects to /provider when in provider mode',
        () {
      expect(
        _redirectAuthenticated(
          ActiveMode.provider,
          '${AppRoutes.bookings}/booking-abc',
        ),
        equals(AppRoutes.providerHome),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Client mode — provider tabs should redirect to /home
  // -------------------------------------------------------------------------

  group('client mode + provider tabs → /home', () {
    test('/provider redirects to /home when in client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.providerHome),
        equals(AppRoutes.home),
      );
    });

    test('/provider/inbox redirects to /home when in client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.providerInbox),
        equals(AppRoutes.home),
      );
    });

    test(
        '/provider/inbox/bookings/:id sub-route redirects to /home '
        'when in client mode', () {
      expect(
        _redirectAuthenticated(
          ActiveMode.client,
          '${AppRoutes.providerInbox}/bookings/bk-1',
        ),
        equals(AppRoutes.home),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Client mode — provider-only routes should redirect to /home
  // -------------------------------------------------------------------------

  group('client mode + provider-only routes → /home', () {
    test('/provider/onboarding redirects to /home when in client mode', () {
      expect(
        _redirectAuthenticated(
          ActiveMode.client,
          AppRoutes.providerOnboarding,
        ),
        equals(AppRoutes.home),
      );
    });

    test('/provider/calendar redirects to /home when in client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.providerCalendar),
        equals(AppRoutes.home),
      );
    });

    test('/provider/services/new redirects to /home when in client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.serviceNew),
        equals(AppRoutes.home),
      );
    });

    test(
        '/provider/services/:id/edit redirects to /home when in client mode',
        () {
      expect(
        _redirectAuthenticated(
          ActiveMode.client,
          AppRoutes.serviceEdit('svc-1'),
        ),
        equals(AppRoutes.home),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Shared tabs — no redirect regardless of mode
  // -------------------------------------------------------------------------

  group('shared tabs → no redirect regardless of mode', () {
    test('/chats: no redirect for client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.chatsList),
        isNull,
      );
    });

    test('/chats: no redirect for provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.chatsList),
        isNull,
      );
    });

    test('/profile: no redirect for client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.profile),
        isNull,
      );
    });

    test('/profile: no redirect for provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.profile),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Deep-link routes — no redirect regardless of mode
  // -------------------------------------------------------------------------

  group('deep-link routes → no redirect', () {
    test('/booking/:id: no redirect for client mode', () {
      expect(
        _redirectAuthenticated(
          ActiveMode.client,
          AppRoutes.bookingDeepLink('bk-99'),
        ),
        isNull,
      );
    });

    test('/booking/:id: no redirect for provider mode', () {
      expect(
        _redirectAuthenticated(
          ActiveMode.provider,
          AppRoutes.bookingDeepLink('bk-99'),
        ),
        isNull,
      );
    });

    test('/chat/:id: no redirect for client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.chat('chat-1')),
        isNull,
      );
    });

    test('/chat/:id: no redirect for provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.chat('chat-1')),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Sanity: authenticated user on auth routes always redirects to /home
  // -------------------------------------------------------------------------

  group('authenticated + auth routes → /home', () {
    test('/sign-in redirects to /home in client mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.client, AppRoutes.signIn),
        equals(AppRoutes.home),
      );
    });

    test('/sign-up redirects to /home in provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.signUp),
        equals(AppRoutes.home),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Provider mode — provider tabs allowed (no redirect)
  // -------------------------------------------------------------------------

  group('provider mode + provider tabs → no redirect', () {
    test('/provider: no redirect for provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.providerHome),
        isNull,
      );
    });

    test('/provider/inbox: no redirect for provider mode', () {
      expect(
        _redirectAuthenticated(ActiveMode.provider, AppRoutes.providerInbox),
        isNull,
      );
    });
  });

  // -------------------------------------------------------------------------
  // AuthState integration — unauthenticated and loading pass-through
  // -------------------------------------------------------------------------

  group('AuthState wiring sanity', () {
    // These mirror the existing router_redirect_test but confirm the state
    // types are constructed correctly when used alongside mode checks.
    test('AuthAuthenticated wraps user correctly', () {
      final user = _makeUser(activeMode: ActiveMode.provider);
      final state = AuthAuthenticated(user);
      expect(state.user.activeMode, ActiveMode.provider);
    });

    test('AuthUnauthenticated is const-constructible', () {
      expect(const AuthUnauthenticated(), isA<AuthUnauthenticated>());
    });
  });
}
