import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../application/auth/auth_providers.dart';
import '../application/auth/auth_state.dart';
import '../application/onboarding/onboarding_provider.dart';
import '../application/service/service_providers.dart';
import '../application/user/user_providers.dart';
import '../domain/enums/active_mode.dart';
import '../features/auth/otp_lab/otp_lab_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/booking/booking_detail_page.dart';
import '../features/provider/provider_calendar_page.dart';
import '../features/booking/booking_list_page.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/chats_list_page.dart';
import '../features/home/home_page.dart';
import '../features/legal/legal_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/profile/profile_page.dart';
import '../features/provider/identity/identity_capture_host_page.dart';
import '../features/provider/identity/identity_guide_page.dart';
import '../features/provider/identity/identity_status_page.dart';
import '../features/provider/identity/identity_web_unavailable_page.dart';
import '../features/provider/provider_dashboard_page.dart';
import '../features/provider/provider_inbox_page.dart';
import '../features/provider/provider_onboarding_page.dart';
import '../features/provider/public_provider_profile_page.dart';
import '../features/provider/service_form_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/profile/blocked_users_page.dart';
import '../features/report/report_page.dart';
import '../features/review/review_form_page.dart';
import '../features/review/rating_summary.dart';
import '../features/review/user_reviews_page.dart';
import '../features/service/service_detail_page.dart';
import 'app_shell.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const otpLab = '/otp-lab';
  static const home = '/home';
  static const bookings = '/bookings';
  static const providerHome = '/provider';
  static const providerInbox = '/provider/inbox';
  static const providerOnboarding = '/provider/onboarding';
  static const serviceNew = '/provider/services/new';
  static const providerCalendar = '/provider/calendar';

  // Identity verification journey (E6): status/entry, guide+consent, capture,
  // and the web explainer the entry redirects to on web (AC-C04).
  static const identityStatus = '/provider/identity';
  static const identityGuide = '/provider/identity/guide';
  static const identityCapture = '/provider/identity/capture';
  static const identityUnavailable = '/provider/identity/unavailable';

  static String serviceDetail(String serviceId) => '/service/$serviceId';
  static String bookingDetail(String bookingId) => '/bookings/$bookingId';

  /// Deep-link path for notifications - resolves outside the shell to avoid
  /// duplicate-key conflict with the shell-nested /bookings/:bookingId route.
  static String bookingDeepLink(String bookingId) => '/booking/$bookingId';
  static String serviceEdit(String serviceId) =>
      '/provider/services/$serviceId/edit';
  static String providerBookingDetail(String bookingId) =>
      '/provider/inbox/bookings/$bookingId';

  // Parameterised helpers
  static const notifications = '/notifications';
  static const blockedUsers = '/blocked-users';
  static const chatsList = '/chats';

  static const profile = '/profile';
  static const myReviews = '/my-reviews';

  // Legal documents - served in-app from bundled assets (no remote link).
  static const legalTerms = '/legal/terms';
  static const legalPrivacy = '/legal/privacy';

  static String chat(String chatId) => '/chat/$chatId';
  static String review(String bookingId) => '/review/$bookingId';

  /// Reads back what [userReviews] wrote. Exported so the route builder and
  /// its test share ONE implementation: a test that re-derives the parsing
  /// stays green when the builder changes.
  static RatingSource ratingSourceFromQuery(String? as) =>
      as == 'provider' ? RatingSource.provider : RatingSource.client;

  /// Reviews received by [uid]. [asProvider] tells the page WHICH reputation
  /// it is showing: a provider's public rating comes from the server-owned
  /// aggregate, a client's from their recent reviews. The page cannot guess,
  /// and guessing wrong shows "Nouveau" for ever on one side or a floorless
  /// average on the other.
  static String userReviews(String uid, {required bool asProvider}) =>
      '/reviews/$uid?as=${asProvider ? 'provider' : 'client'}';
  static String report({required String type, required String id}) =>
      '/report/$type/$id';
  static String providerProfile(String uid) => '/provider-profile/$uid';
}

// ---------------------------------------------------------------------------
// RouterNotifier - bridges Riverpod auth state to GoRouter refreshListenable
// ---------------------------------------------------------------------------

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
    _ref.listen<ActiveMode>(activeModeProvider, (_, __) => notifyListeners());
    _ref.listen<bool>(onboardingDoneProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authNotifierProvider);

    return authAsync.when(
      loading: () => null,
      error: (_, __) => AppRoutes.signIn,
      data: (authState) {
        final loc = state.matchedLocation;
        // Legal documents are always accessible (before auth, during onboarding).
        if (loc.startsWith('/legal')) return null;
        // OTP lab is debug-only - block in release builds.
        if (kDebugMode && loc == AppRoutes.otpLab) return null;
        if (!kDebugMode && loc == AppRoutes.otpLab) return AppRoutes.signIn;
        final isAuthRoute = loc == AppRoutes.signIn || loc == AppRoutes.signUp;
        final isOnboardingRoute = loc == AppRoutes.onboarding;

        // First launch: the onboarding screen (which carries the CGU consent
        // gate) must be shown BEFORE anything else - including sign-in - so
        // consent is collected at app opening, not after authentication.
        final onboardingDone = _ref.read(onboardingDoneProvider);
        if (!onboardingDone) {
          return isOnboardingRoute ? null : AppRoutes.onboarding;
        }

        // ---- Unauthenticated: guest browsing ----
        //
        // A visitor with no account explores the public surface: the discovery
        // home with its search and filters, a service detail, a public provider
        // profile, and a user's received reviews. Everything else is gated at
        // its entry point, and the gate carries the visitor's intention with it
        // so signing in resumes what they were doing.
        if (authState is AuthUnauthenticated) {
          if (isAuthRoute) return null;
          // Consent already collected: leaving onboarding lands on public home,
          // not on sign-in. This is the "continue without an account" door.
          if (isOnboardingRoute) return AppRoutes.home;
          if (isGuestAllowed(loc)) return null;
          return signInWithReturnTo(state.uri);
        }

        // ---- Authenticated ----
        if (authState is AuthAuthenticated) {
          if (isOnboardingRoute) return AppRoutes.home;
          if (isAuthRoute) {
            // Return to intention: a gated route or action sent the visitor
            // here with ?redirect=<internal path>, which may carry its own
            // intent (e.g. /service/:id?book=1). Resume there.
            return postAuthTarget(state.uri) ?? AppRoutes.home;
          }

          // When switching modes, redirect to the right home tab.
          // Uses startsWith to catch sub-routes (e.g. /bookings/:id,
          // /provider/inbox/bookings/:id) that live inside the shell branch.
          final mode = _ref.read(activeModeProvider);
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
          // Block deep-link access to provider-only screens when in client mode.
          final isProviderOnlyRoute =
              loc.startsWith('/provider/onboarding') ||
              loc.startsWith('/provider/calendar') ||
              loc.startsWith('/provider/services');
          if (mode == ActiveMode.client && isProviderOnlyRoute) {
            return AppRoutes.home;
          }
        }
        return null;
      },
    );
  }

  /// The routes a signed-out visitor may view.
  ///
  /// An ALLOWLIST, deliberately: a deny list would open every route added later
  /// by default, and the ones added later are the private ones. `/legal` is
  /// handled earlier in [redirect], before auth is even consulted.
  ///
  /// Each entry must be backed by a publicly readable Firestore rule, or the
  /// screen opens onto an error state, which is worse than a sign-in prompt:
  ///   /home             services, providers, provider_ratings, public_profiles
  ///   /service/:id      the same
  ///   /provider-profile the same
  ///   /reviews/:uid     reviews, filtered on `hidden == false` by the query
  @visibleForTesting
  static bool isGuestAllowed(String loc) {
    return loc == AppRoutes.home ||
        loc.startsWith('/service/') ||
        loc.startsWith('/provider-profile/') ||
        loc.startsWith('/reviews/');
  }

  /// Sign-in, carrying where the visitor was trying to go.
  ///
  /// Takes the full [uri] rather than the matched path so a deep link's own
  /// query survives the round trip.
  @visibleForTesting
  static String signInWithReturnTo(Uri uri) {
    final target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    if (target.isEmpty || target == AppRoutes.home) return AppRoutes.signIn;
    return Uri(
      path: AppRoutes.signIn,
      queryParameters: {'redirect': target},
    ).toString();
  }

  /// Tab, LF and CR: the three characters the WHATWG URL parser removes from a
  /// URL before it parses anything. Hoisted so [postAuthTarget], which runs on
  /// every redirect decision, does not rebuild the pattern each time.
  static final _urlStrippedChars = RegExp(r'[\t\n\r]');

  /// Where to land after signing in, read back from `?redirect=`.
  ///
  /// Only in-app paths are honoured: the target must start with exactly one
  /// slash, so `//evil.example` (protocol-relative, i.e. an absolute URL to a
  /// host an attacker chose) is refused.
  ///
  /// The target is normalised BEFORE that decision, and the normalisation is
  /// part of the guard, not cosmetics: a browser rewrites a URL before parsing
  /// it, so a raw string that reads as internal can still reach the network as
  /// somebody else's host. Two spellings did exactly that, and both are folded
  /// away here:
  ///   `/\evil.example`       a backslash IS a slash in a special-scheme URL
  ///   `/<tab>/evil.example`  tab, LF and CR are removed before parsing
  /// Both are `//evil.example` by the time the browser resolves them. Deciding
  /// on the raw string accepted them; deciding on the normalised one does not.
  ///
  /// Returns the NORMALISED target rather than the string that arrived. Handing
  /// back the original would mean approving a value on one spelling of itself
  /// and then shipping another, and would leave native (which folds nothing)
  /// and web (which folds everything) resolving one redirect to two different
  /// places. Returns null when there is nothing safe to resume.
  @visibleForTesting
  static String? postAuthTarget(Uri uri) {
    final target = uri.queryParameters['redirect'];
    if (target == null) return null;
    // Folding backslashes across the whole string is stricter than WHATWG,
    // which stops folding at the `?`. Deliberate: no in-app redirect this app
    // writes carries a backslash, and one rule over the whole value is one
    // rule to audit.
    final normalised = target
        .replaceAll(_urlStrippedChars, '')
        .replaceAll(r'\', '/');
    if (!normalised.startsWith('/') || normalised.startsWith('//')) return null;
    return normalised;
  }
}

// ---------------------------------------------------------------------------
// Stable branch navigator keys (module-level so they never change identity)
// ---------------------------------------------------------------------------

final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final _shellNavigatorBookingsKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellBookings',
);
final _shellNavigatorProviderKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellProvider',
);
final _shellNavigatorInboxKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellInbox',
);
final _shellNavigatorChatsKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellChats',
);
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

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
      // ---- First-launch onboarding ----
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (_, __) => const OnboardingPage(),
      ),

      // ---- Legal documents (in-app, full screen, no remote link) ----
      GoRoute(
        path: '/legal/:doc',
        name: 'legal',
        builder: (context, state) {
          final doc = LegalDoc.fromKey(state.pathParameters['doc']);
          final l10n = AppLocalizations.of(context)!;
          final title = doc == LegalDoc.privacy
              ? l10n.legalPrivacyTitle
              : l10n.legalTermsTitle;
          return LegalPage(doc: doc, title: title);
        },
      ),

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
      // ---- OTP Lab (debug only - stripped from release builds) ----
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.otpLab,
          name: 'otp-lab',
          builder: (_, __) => const OtpLabPage(),
        ),
      // ---- Provider onboarding (outside shell - full screen) ----
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

      // ---- Identity verification (outside shell - full screen, E6) ----
      // Status/entry: the hub line opens this; a provider with no file lands
      // on "not verified" with the path to start.
      GoRoute(
        path: AppRoutes.identityStatus,
        name: 'identity-status',
        builder: (context, _) => IdentityStatusPage(
          onStartVerification: () =>
              GoRouter.of(context).push(AppRoutes.identityGuide),
        ),
      ),
      // Guide + consent. On web it redirects to the explainer (AC-C04, E15):
      // the entry carries the message, never a filled-in guide that dead-ends.
      GoRoute(
        path: AppRoutes.identityGuide,
        name: 'identity-guide',
        redirect: (_, __) => kIsWeb ? AppRoutes.identityUnavailable : null,
        builder: (context, _) => IdentityGuidePage(
          onStart: () => GoRouter.of(context).push(AppRoutes.identityCapture),
          onOpenTerms: () => GoRouter.of(context).push(AppRoutes.legalTerms),
        ),
      ),
      // Capture journey. Also web-guarded, so a direct link never reaches a
      // camera screen that cannot run (AC-C04).
      GoRoute(
        path: AppRoutes.identityCapture,
        name: 'identity-capture',
        redirect: (_, __) => kIsWeb ? AppRoutes.identityUnavailable : null,
        builder: (context, _) => IdentityCaptureHostPage(
          onFinished: () => GoRouter.of(context).go(AppRoutes.identityStatus),
        ),
      ),
      GoRoute(
        path: AppRoutes.identityUnavailable,
        name: 'identity-unavailable',
        builder: (_, __) => const IdentityWebUnavailablePage(),
      ),

      // ---- Service form - new (outside shell) ----
      GoRoute(
        path: AppRoutes.serviceNew,
        name: 'service-new',
        builder: (_, __) => const ServiceFormPage(),
      ),

      // ---- Service form - edit (outside shell) ----
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
          // Branch 0 - Client: Home
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

          // Branch 1 - Client: Bookings
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

          // Branch 2 - Provider: Dashboard
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

          // Branch 3 - Provider: Inbox
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

          // Branch 4 - Chats (shared between client and provider modes)
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

          // Branch 5 - Profile & Settings (shared between client and provider)
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

      // ---- Service detail (outside shell - full-screen) ----
      GoRoute(
        path: '/service/:serviceId',
        name: 'service-detail',
        builder: (_, state) => ServiceDetailPage(
          serviceId: state.pathParameters['serviceId']!,
          // Return to intention: a visitor who signed in from the booking gate
          // comes back here with ?book=1, and the sheet reopens by itself.
          autoOpenBooking: state.uri.queryParameters['book'] == '1',
        ),
      ),

      // ---- Booking detail deep-link (notifications, external links) ----
      // Uses /booking/:id (singular) to avoid conflict with the shell-nested
      // /bookings/:id route which GoRouter would otherwise match twice.
      GoRoute(
        path: '/booking/:bookingId',
        name: 'booking-deep-link',
        builder: (_, state) =>
            BookingDetailPage(bookingId: state.pathParameters['bookingId']!),
      ),

      // ---- Chat ----
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat',
        builder: (_, state) =>
            ChatPage(chatId: state.pathParameters['chatId']!),
      ),

      // ---- Review form ----
      GoRoute(
        path: '/review/:bookingId',
        name: 'review',
        builder: (_, state) =>
            ReviewFormPage(bookingId: state.pathParameters['bookingId']!),
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

      // ---- My reviews (dedicated page, opened from profile) ----
      GoRoute(
        path: AppRoutes.myReviews,
        name: 'my-reviews',
        builder: (_, __) => const MyReviewsPage(),
      ),

      // ---- Any user's received reviews (e.g. a client, from a booking) ----
      GoRoute(
        path: '/reviews/:uid',
        name: 'user-reviews',
        builder: (_, state) => UserReviewsPage(
          userId: state.pathParameters['uid']!,
          source: AppRoutes.ratingSourceFromQuery(
            state.uri.queryParameters['as'],
          ),
        ),
      ),

      // ---- Public provider profile ----
      GoRoute(
        path: '/provider-profile/:uid',
        name: 'provider-profile',
        builder: (_, state) =>
            PublicProviderProfilePage(providerId: state.pathParameters['uid']!),
      ),

      // ---- Notifications ----
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (_, __) => const NotificationsPage(),
      ),

      // ---- Blocked accounts management ----
      GoRoute(
        path: AppRoutes.blockedUsers,
        name: 'blocked-users',
        builder: (_, __) => const BlockedUsersPage(),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Service edit loader - fetches service before showing form
// ---------------------------------------------------------------------------

class _ServiceEditLoader extends ConsumerWidget {
  const _ServiceEditLoader({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return serviceAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
