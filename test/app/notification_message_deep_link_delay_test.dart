// Investigates hypothesis B of the message-notification-tap bug
// (tmp/outalma-notif-tap/BRIEF.md): "the fixed 350ms delay in
// _handleNotificationTap (app.dart:90) races the router's own redirect, so
// the redirect can overwrite the just-pushed deep link".
//
// Two things must both be true for that mechanism to explain the reported
// symptom (tapping a *message* notification does not open the chat):
//   1. A pending/late-resolving redirect must be able to overwrite a route
//      that was pushed while it was still in flight.
//   2. The route a message notification resolves to (`/chat/:chatId`, see
//      notification_route.dart) must be one the redirect can actually touch.
//
// Neither holds, so this hypothesis does NOT confirm for this bug:
//   - (1) is refuted below with the real go_router package this app pins
//     (14.8.1): pushing a route while an earlier, slower-resolving redirect
//     is still pending is NOT overwritten once it resolves. go_router
//     re-evaluates redirects against whatever the CURRENT location is at
//     resolution time, not a stale snapshot from when it was triggered.
//   - (2) is refuted below by mirroring RouterNotifier.redirect's tab
//     classification (router.dart:180-205, same test-double pattern as
//     router_full_test.dart): `/chat/:chatId` matches none of isClientTab,
//     isProviderTab or isSharedTab, so no mode value, however stale, ever
//     redirects it.
//
// The 350ms is still a magic number (the docstring itself calls out that
// nothing guarantees it), but it is not what breaks the message-tap deep
// link. Left untouched per BRIEF.md's instruction not to fix what a test
// does not confirm.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_notification.dart';

void main() {
  group(
    'hypothesis B (1/2): a pending redirect cannot overwrite a later push',
    () {
      Future<String> runRace(
        WidgetTester tester, {
        required Duration pendingRedirectDelay,
        required bool pushBeforeNotify,
      }) async {
        var authReady = false;
        final refresh = ChangeNotifier();
        final router = GoRouter(
          initialLocation: '/sign-in',
          refreshListenable: refresh,
          redirect: (context, state) async {
            final loc = state.matchedLocation;
            if (!authReady) return loc == '/sign-in' ? null : '/sign-in';
            if (loc == '/sign-in') {
              // Models the real redirect settling slower than the tap
              // handler's fixed 350ms wait (e.g. a slow cold-start device).
              await Future<void>.delayed(pendingRedirectDelay);
              return '/home';
            }
            return null;
          },
          routes: [
            GoRoute(
              path: '/sign-in',
              builder: (_, __) => const Scaffold(body: Text('signin')),
            ),
            GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: Text('home')),
            ),
            GoRoute(
              path: '/chat/:id',
              builder: (_, __) => const Scaffold(body: Text('chat')),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('signin'), findsOneWidget);

        authReady = true;
        if (pushBeforeNotify) {
          unawaited(router.push('/chat/42'));
          refresh.notifyListeners();
        } else {
          refresh.notifyListeners();
          unawaited(router.push('/chat/42'));
        }
        // Give the slow pending redirect time to resolve too, well past
        // pendingRedirectDelay, then let everything settle.
        await tester.pump(pendingRedirectDelay + const Duration(seconds: 1));
        await tester.pumpAndSettle();

        if (find.text('chat').evaluate().isNotEmpty) return 'chat';
        if (find.text('home').evaluate().isNotEmpty) return 'home';
        return 'signin';
      }

      testWidgets(
        'push then a slower pending redirect (350ms delay, 500ms redirect)',
        (tester) async {
          final landed = await runRace(
            tester,
            pendingRedirectDelay: const Duration(milliseconds: 500),
            pushBeforeNotify: false,
          );
          expect(
            landed,
            'chat',
            reason:
                'if this were "home", the delay-vs-redirect race would be '
                'real and hypothesis B would confirm',
          );
        },
      );

      testWidgets('push issued before the redirect trigger fires at all', (
        tester,
      ) async {
        final landed = await runRace(
          tester,
          pendingRedirectDelay: const Duration(milliseconds: 500),
          pushBeforeNotify: true,
        );
        expect(landed, 'chat');
      });
    },
  );

  group('hypothesis B (2/2): /chat/:id is outside the mode-redirect logic', () {
    // Mirrors RouterNotifier.redirect's authenticated-branch tab
    // classification (router.dart:180-205), i.e. the ONLY logic in that
    // method that depends on `mode`, and so the only logic a late/stale
    // mode value could possibly make race with a push. Same test-double
    // approach as test/app/router_full_test.dart.
    bool isModeGated(String loc) {
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
      final isProviderOnlyRoute =
          loc.startsWith('/provider/onboarding') ||
          loc.startsWith('/provider/calendar') ||
          loc.startsWith('/provider/services');
      return (!isSharedTab && (isClientTab || isProviderTab)) ||
          isProviderOnlyRoute;
    }

    test('a message deep link is never mode-gated', () {
      expect(isModeGated(AppRoutes.chat('c1')), isFalse);
    });

    test('sanity: a booking deep link IS mode-gated (contrast case)', () {
      // Confirms isModeGated actually detects the gated shape, so the
      // negative result above is meaningful and not a bug in this mirror.
      expect(isModeGated(AppRoutes.bookingDetail('b1')), isTrue);
    });

    test('sanity: activeModeForAudience can return a real mode (the '
        'precondition for this race to matter at all)', () {
      expect(
        activeModeForAudience(NotificationAudience.provider),
        ActiveMode.provider,
      );
    });
  });
}
