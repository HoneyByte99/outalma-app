// Guest-browsing allowlist (Lot 4): exercises the REAL
// RouterNotifier.isGuestAllowed used inside redirect(), so this stays honest
// even though the surrounding GoRouterState is awkward to construct directly.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/router.dart';

void main() {
  group('RouterNotifier.isGuestAllowed', () {
    test('allows the public discovery + detail surfaces', () {
      expect(RouterNotifier.isGuestAllowed(AppRoutes.home), isTrue);
      expect(
        RouterNotifier.isGuestAllowed(AppRoutes.serviceDetail('svc-1')),
        isTrue,
      );
      expect(
        RouterNotifier.isGuestAllowed(AppRoutes.providerProfile('prov-1')),
        isTrue,
      );
      expect(
        RouterNotifier.isGuestAllowed(AppRoutes.userReviews('user-1')),
        isTrue,
      );
    });

    test('denies bookings, chats, profile and provider tooling', () {
      for (final loc in [
        AppRoutes.bookings,
        AppRoutes.bookingDetail('b-1'),
        AppRoutes.providerHome,
        AppRoutes.providerInbox,
        AppRoutes.providerOnboarding,
        AppRoutes.chatsList,
        AppRoutes.profile,
        AppRoutes.notifications,
        AppRoutes.myReviews,
      ]) {
        expect(
          RouterNotifier.isGuestAllowed(loc),
          isFalse,
          reason: '$loc must require sign-in',
        );
      }
    });

    test(
      'does not confuse /provider/... tooling with /provider-profile/...',
      () {
        // Provider tooling shares a prefix with the public profile route; the
        // allowlist must match the profile but not the tooling.
        expect(
          RouterNotifier.isGuestAllowed(AppRoutes.providerProfile('p1')),
          isTrue,
        );
        expect(
          RouterNotifier.isGuestAllowed('/provider/services/new'),
          isFalse,
        );
      },
    );
  });

  group('RouterNotifier.postAuthTarget (return-to-intention)', () {
    test('returns the internal redirect path, preserving its intent query', () {
      expect(
        RouterNotifier.postAuthTarget(Uri.parse('/sign-in?redirect=/home')),
        '/home',
      );
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('/sign-in?redirect=/service/abc%3Fbook%3D1'),
        ),
        '/service/abc?book=1',
      );
    });

    test('returns null when there is no redirect', () {
      expect(RouterNotifier.postAuthTarget(Uri.parse('/sign-in')), isNull);
    });

    test('ignores non-internal (open-redirect) targets', () {
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('/sign-in?redirect=https://evil.example.com'),
        ),
        isNull,
      );
    });
  });
}
