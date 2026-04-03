import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth/auth_providers.dart';
import '../application/auth/auth_state.dart';
import '../application/service/service_providers.dart';
import '../application/user/user_providers.dart';
import '../domain/enums/active_mode.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/booking/booking_detail_page.dart';
import '../features/booking/booking_list_page.dart';
import '../features/home/home_page.dart';
import '../features/provider/provider_dashboard_page.dart';
import '../features/provider/provider_inbox_page.dart';
import '../features/provider/provider_onboarding_page.dart';
import '../features/provider/service_form_page.dart';
import '../features/service/service_detail_page.dart';
import '../features/switch_mode/switch_mode_page.dart';
import 'app_shell.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const switchMode = '/switch-mode';
  static const bookings = '/bookings';
  static const providerHome = '/provider';
  static const providerInbox = '/provider/inbox';
  static const providerOnboarding = '/provider/onboarding';
  static const serviceNew = '/provider/services/new';

  static String serviceDetail(String serviceId) => '/service/$serviceId';
  static String bookingDetail(String bookingId) => '/bookings/$bookingId';
  static String serviceEdit(String serviceId) =>
      '/provider/services/$serviceId/edit';
  static String providerBookingDetail(String bookingId) =>
      '/provider/inbox/bookings/$bookingId';
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
    _ref.listen<ActiveMode>(
      activeModeProvider,
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
          if (isAuthRoute) return AppRoutes.home;

          // When switching modes, redirect to the right home tab.
          final mode = _ref.read(activeModeProvider);
          final loc = state.matchedLocation;
          final isClientTab =
              loc == AppRoutes.home || loc == AppRoutes.bookings;
          final isProviderTab = loc == AppRoutes.providerHome ||
              loc == AppRoutes.providerInbox;

          if (mode == ActiveMode.provider && isClientTab) {
            return AppRoutes.providerHome;
          }
          if (mode == ActiveMode.client && isProviderTab) {
            return AppRoutes.home;
          }
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

      // ---- Provider onboarding (outside shell — full screen) ----
      GoRoute(
        path: AppRoutes.providerOnboarding,
        name: 'provider-onboarding',
        builder: (_, __) => const ProviderOnboardingPage(),
      ),

      // ---- Service form — new (outside shell) ----
      GoRoute(
        path: AppRoutes.serviceNew,
        name: 'service-new',
        builder: (_, __) => const ServiceFormPage(),
      ),

      // ---- Service form — edit (outside shell) ----
      GoRoute(
        path: '/provider/services/:serviceId/edit',
        name: 'service-edit',
        builder: (_, state) {
          final serviceId = state.pathParameters['serviceId']!;
          return _ServiceEditLoader(serviceId: serviceId);
        },
      ),

      // ---- App shell with bottom nav (4 branches) ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          // Branch 0 — Client: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),

          // Branch 1 — Client: Bookings
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

          // Branch 2 — Provider: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.providerHome,
                name: 'provider-home',
                builder: (_, __) => const ProviderDashboardPage(),
              ),
            ],
          ),

          // Branch 3 — Provider: Inbox
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.providerInbox,
                name: 'provider-inbox',
                builder: (_, __) => const ProviderInboxPage(),
                routes: [
                  GoRoute(
                    path: 'bookings/:bookingId',
                    name: 'provider-booking-detail',
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

      // ---- Booking detail (accessible from notifications etc.) ----
      GoRoute(
        path: '/bookings/:bookingId',
        name: 'booking-detail-root',
        builder: (_, state) => BookingDetailPage(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Service edit loader — fetches service before showing form
// ---------------------------------------------------------------------------

class _ServiceEditLoader extends ConsumerWidget {
  const _ServiceEditLoader({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return serviceAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Service introuvable')),
      ),
      data: (service) {
        if (service == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Service introuvable')),
          );
        }
        return ServiceFormPage(existing: service);
      },
    );
  }
}
