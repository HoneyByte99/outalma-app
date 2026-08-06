// Tests the consent-presence gate added to RouterNotifier (P0 legal, CDP
// Senegal loi 2008-12 art. 11 / RGPD). A signed-in account with no
// server-side consent record is a "zombie" (the sign-up consent Cloud Function
// AND its local rollback both failed) and must be routed to the recovery flow
// instead of being let into the app.
//
// Exercises the REAL predicate RouterNotifier.needsConsentFinalization plus a
// faithful mirror of the authenticated redirect branch to confirm the gate
// takes priority and routes to /finalize-signup.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';

AppUser _user({UserConsent? consent}) => AppUser(
  id: 'uid-1',
  displayName: 'Alice',
  email: 'alice@example.com',
  country: 'SN',
  activeMode: ActiveMode.client,
  createdAt: DateTime(2024).toUtc(),
  consent: consent,
);

/// Mirrors the top of RouterNotifier.redirect's authenticated branch: the
/// consent gate runs first and wins over every other rule.
String? _authenticatedRedirect(AppUser user, String loc) {
  final isFinalizeRoute = loc == AppRoutes.finalizeSignUp;
  if (RouterNotifier.needsConsentFinalization(user)) {
    return isFinalizeRoute ? null : AppRoutes.finalizeSignUp;
  }
  if (isFinalizeRoute) return AppRoutes.home;
  return null; // (mode-based rules omitted; covered elsewhere)
}

void main() {
  group('RouterNotifier.needsConsentFinalization', () {
    test('true when consent is absent (null)', () {
      expect(RouterNotifier.needsConsentFinalization(_user()), isTrue);
    });

    test('true when consent map exists but termsVersion is null', () {
      expect(
        RouterNotifier.needsConsentFinalization(
          _user(consent: const UserConsent()),
        ),
        isTrue,
      );
    });

    test('false when a termsVersion is present', () {
      expect(
        RouterNotifier.needsConsentFinalization(
          _user(consent: const UserConsent(termsVersion: '2026-06-07')),
        ),
        isFalse,
      );
    });
  });

  group('consent gate redirect (authenticated)', () {
    test('zombie account on /home is redirected to /finalize-signup', () {
      expect(
        _authenticatedRedirect(_user(), AppRoutes.home),
        equals(AppRoutes.finalizeSignUp),
      );
    });

    test('zombie account on a deep route is redirected too', () {
      expect(
        _authenticatedRedirect(_user(), AppRoutes.bookings),
        equals(AppRoutes.finalizeSignUp),
      );
    });

    test('zombie account already on /finalize-signup stays there', () {
      expect(_authenticatedRedirect(_user(), AppRoutes.finalizeSignUp), isNull);
    });

    test('consented account is never trapped on /finalize-signup', () {
      final consented = _user(
        consent: const UserConsent(termsVersion: '2026-06-07'),
      );
      expect(
        _authenticatedRedirect(consented, AppRoutes.finalizeSignUp),
        equals(AppRoutes.home),
      );
    });

    test('consented account on /home passes through', () {
      final consented = _user(
        consent: const UserConsent(termsVersion: '2026-06-07'),
      );
      expect(_authenticatedRedirect(consented, AppRoutes.home), isNull);
    });
  });
}
