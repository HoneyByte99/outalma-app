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
import '../features/provider/provider_calendar_page.dart';
import '../features/booking/booking_list_page.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/chats_list_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/provider/provider_dashboard_page.dart';
import '../features/provider/provider_inbox_page.dart';
import '../features/provider/provider_onboarding_page.dart';
import '../features/provider/public_provider_profile_page.dart';
import '../features/provider/service_form_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/report/report_page.dart';
import '../features/review/review_form_page.dart';
import '../features/service/service_detail_page.dart';
import 'app_shell.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const bookings = '/bookings';
  static const providerHome = '/provider';
  static const providerInbox = '/provider/inbox';
  static const providerOnboarding = '/provider/onboarding';
  static const serviceNew = '/provider/services/new';
  static const providerCalendar = '/provider/calendar';

  static String serviceDetail(String serviceId) => '/service/$serviceId';
  static String bookingDetail(String bookingId) => '/bookings/$bookingId';
  /// Deep-link path for notifications — resolves outside the shell to avoid
  /// duplicate-key conflict with the shell-nested /bookings/:bookingId route.
  static String bookingDeepLink(String bookingId) => '/booking/$bookingId';
  static String serviceEdit(String serviceId) =>
      '/provider/services/$serviceId/edit';
  static String providerBookingDetail(String bookingId) =>
      '/provider/inbox/bookings/$bookingId';

  // Parameterised helpers
  static const notifications = '/notifications';
  static const chatsList = '/chats';

  static const profile = '/profile';

  static String chat(String chatId) => '/chat/$chatId';
  static String review(String bookingId) => '/review/$bookingId';
  static String report({required String type, required String id}) =>
      '/report/$type/$id';
  static String providerProfile(String uid) => '/provider-profile/$uid';
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
        final loc = state.matchedLocation;
        final isAuthRoute = loc == AppRoutes.signIn ||
            loc == AppRoutes.signUp;

        // ---- Unauthenticated ----
        if (authState is AuthUnauthenticated) {
          return isAuthRoute ? null : AppRoutes.signIn;
        }

        // ---- Authenticated ----
        if (authState is AuthAuthenticated) {
          if (isAuthRoute) return AppRoutes.home;

          // When switching modes, redirect to the right home tab.
          final mode = _ref.read(activeModeProvider);
          final isClientTab =
              loc == AppRoutes.home || loc == AppRoutes.bookings;
          final isProviderTab = loc == AppRoutes.providerHome ||
              loc == AppRoutes.providerInbox;
          final isSharedTab =
              loc == AppRoutes.chatsList || loc == AppRoutes.profile;

          if (!isSharedTab && mode == ActiveMode.provider && isClientTab) {
            return AppRoutes.providerHome;
          }
          if (!isSharedTab && mode == ActiveMode.client && isProviderTab) {
            return AppRoutes.home;
          }
        }
        return null;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stable branch navigator keys (module-level so they never change identity)
// ---------------------------------------------------------------------------

final _shellNavigatorHomeKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorBookingsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellBookings');
final _shellNavigatorProviderKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellProvider');
final _shellNavigatorInboxKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellInbox');
final _shellNavigatorChatsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellChats');
final _shellNavigatorProfileKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

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
      // ---- Provider onboarding (outside shell — full screen) ----
      GoRoute(
        path: AppRoutes.providerOnboarding,
        name: 'provider-onboarding',
        builder: (_, __) => const ProviderOnboardingPage(),
      ),

      // ---- Provider calendar (outside shell) ----
      GoRoute(
        path: AppRoutes.providerCalendar,
        name: 'provider-calendar',
        builder: (_, __) => const ProviderCalendarPage(),
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

      // ---- App shell with bottom nav (5 branches) ----
      // Branch indices: 0=client home, 1=client bookings, 2=provider dashboard,
      // 3=provider inbox, 4=chats (shared between modes).
      // AppShell maps logical tab index to branch index per mode.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          // Branch 0 — Client: Home
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
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
            navigatorKey: _shellNavigatorBookingsKey,
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
            navigatorKey: _shellNavigatorProviderKey,
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
            navigatorKey: _shellNavigatorInboxKey,
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

          // Branch 4 — Chats (shared between client and provider modes)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorChatsKey,
            routes: [
              GoRoute(
                path: AppRoutes.chatsList,
                name: 'chats-list',
                builder: (_, __) => const ChatsListPage(),
              ),
            ],
          ),

          // Branch 5 — Profile & Settings (shared between client and provider)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                builder: (_, __) => const ProfilePage(),
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

      // ---- Booking detail deep-link (notifications, external links) ----
      // Uses /booking/:id (singular) to avoid conflict with the shell-nested
      // /bookings/:id route which GoRouter would otherwise match twice.
      GoRoute(
        path: '/booking/:bookingId',
        name: 'booking-deep-link',
        builder: (_, state) => BookingDetailPage(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),

      // ---- Chat ----
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat',
        builder: (_, state) => ChatPage(
          chatId: state.pathParameters['chatId']!,
        ),
      ),

      // ---- Review form ----
      GoRoute(
        path: '/review/:bookingId',
        name: 'review',
        builder: (_, state) => ReviewFormPage(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),

      // ---- Report ----
      GoRoute(
        path: '/report/:targetType/:targetId',
        name: 'report',
        builder: (_, state) => ReportPage(
          targetType: state.pathParameters['targetType']!,
          targetId: state.pathParameters['targetId']!,
        ),
      ),

      // ---- Public provider profile ----
      GoRoute(
        path: '/provider-profile/:uid',
        name: 'provider-profile',
        builder: (_, state) => PublicProviderProfilePage(
          providerId: state.pathParameters['uid']!,
        ),
      ),

      // ---- Notifications ----
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (_, __) => const NotificationsPage(),
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
