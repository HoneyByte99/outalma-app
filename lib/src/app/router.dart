import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth/auth_providers.dart';
import '../application/auth/auth_state.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/home/home_page.dart';
import '../features/switch_mode/switch_mode_page.dart';

// Route name constants.
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const switchMode = '/switch-mode';
}

/// ChangeNotifier that bridges Riverpod auth state to GoRouter's
/// refreshListenable so the router re-evaluates redirect on auth changes.
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

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
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
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.switchMode,
        name: 'switch-mode',
        builder: (_, __) => const SwitchModePage(),
      ),
    ],
  );
});
