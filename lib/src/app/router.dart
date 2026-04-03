import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth/auth_providers.dart';
import '../application/auth/auth_state.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/booking/booking_detail_page.dart';
import '../features/booking/booking_list_page.dart';
import '../features/home/home_page.dart';
import '../features/service/service_detail_page.dart';
import '../features/switch_mode/switch_mode_page.dart';
import 'app_shell.dart';

// ---------------------------------------------------------------------------
// Route name constants
// ---------------------------------------------------------------------------

abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const switchMode = '/switch-mode';
  static const bookings = '/bookings';

  static String serviceDetail(String serviceId) => '/service/$serviceId';
  static String bookingDetail(String bookingId) => '/bookings/$bookingId';
}

// ---------------------------------------------------------------------------
// RouterNotifier — bridges Riverpod auth state to GoRouter refreshListenable
// ---------------------------------------------------------------------------

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authNotifierProvider);

    return authAsync.when(
      loading: () => null,
      error: (_, __) => AppRoutes.signIn,
      data: (authState) {
        final isAuthRoute = state.matchedLocation == AppRoutes.signIn ||
            state.matchedLocation == AppRoutes.signUp;

        if (authState is AuthUnauthenticated) {
          return isAuthRoute ? null : AppRoutes.signIn;
        }
        if (authState is AuthAuthenticated) {
          return isAuthRoute ? AppRoutes.home : null;
        }
        return null;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ---- Auth ----
      GoRoute(
        path: AppRoutes.signIn,
        name: 'sign-in',
        builder: (_, __) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'sign-up',
        builder: (_, __) => const SignUpPage(),
      ),

      // ---- Switch mode ----
      GoRoute(
        path: AppRoutes.switchMode,
        name: 'switch-mode',
        builder: (_, __) => const SwitchModePage(),
      ),

      // ---- App shell with bottom nav ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),

          // Tab 1 — Bookings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                name: 'bookings',
                builder: (_, __) => const BookingListPage(),
                routes: [
                  GoRoute(
                    path: ':bookingId',
                    name: 'booking-detail',
                    builder: (_, state) => BookingDetailPage(
                      bookingId: state.pathParameters['bookingId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ---- Service detail (outside shell — full-screen) ----
      GoRoute(
        path: '/service/:serviceId',
        name: 'service-detail',
        builder: (_, state) => ServiceDetailPage(
          serviceId: state.pathParameters['serviceId']!,
        ),
      ),
    ],
  );
});
