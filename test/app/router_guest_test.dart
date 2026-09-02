// Locks the three pure decisions that make guest browsing safe, all of them
// static and `@visibleForTesting` on [RouterNotifier]:
//
//   isGuestAllowed      which routes a visitor with no account may view
//   signInWithReturnTo  how the gate carries the visitor's intention along
//   postAuthTarget      what is honoured coming back, the anti-open-redirect
//                       guard, and therefore the reason this file exists
//
// These run on every redirect() decision, so a regression here is either a
// private screen opened to the world or a visitor sent to a domain an attacker
// chose. Each test states the property it protects rather than re-deriving the
// implementation.
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/router.dart';

void main() {
  // -------------------------------------------------------------------------
  // isGuestAllowed: an allowlist, and the prefixes must not leak past it
  // -------------------------------------------------------------------------
  group('isGuestAllowed opens exactly the four public surfaces', () {
    test('the discovery home is public', () {
      expect(RouterNotifier.isGuestAllowed(AppRoutes.home), isTrue);
    });

    test('a service detail is public', () {
      expect(
        RouterNotifier.isGuestAllowed(AppRoutes.serviceDetail('svc_1')),
        isTrue,
      );
    });

    test('a public provider profile is public', () {
      expect(RouterNotifier.isGuestAllowed('/provider-profile/prov_1'), isTrue);
    });

    test('the reviews a user received are public', () {
      expect(RouterNotifier.isGuestAllowed('/reviews/user_1'), isTrue);
    });

    test('a service detail carrying a query is still public', () {
      // redirect() hands over `state.matchedLocation`, but a caller passing the
      // full location must not fall off the allowlist and bounce the visitor.
      expect(RouterNotifier.isGuestAllowed('/service/svc_1?book=1'), isTrue);
    });
  });

  group('isGuestAllowed refuses the private surfaces', () {
    test('bookings are private', () {
      expect(RouterNotifier.isGuestAllowed(AppRoutes.bookings), isFalse);
    });

    test('a booking detail is private', () {
      expect(
        RouterNotifier.isGuestAllowed(AppRoutes.bookingDetail('bk_1')),
        isFalse,
      );
    });

    test('chats are private', () {
      expect(RouterNotifier.isGuestAllowed(AppRoutes.chatsList), isFalse);
    });

    test('the profile is private', () {
      expect(RouterNotifier.isGuestAllowed(AppRoutes.profile), isFalse);
    });

    test('an admin surface is private', () {
      expect(RouterNotifier.isGuestAllowed('/admin'), isFalse);
      expect(RouterNotifier.isGuestAllowed('/admin/reports'), isFalse);
    });

    test('provider service management is private', () {
      expect(RouterNotifier.isGuestAllowed(AppRoutes.serviceNew), isFalse);
      expect(
        RouterNotifier.isGuestAllowed(AppRoutes.serviceEdit('svc_1')),
        isFalse,
      );
    });

    test('an unknown route is private by default', () {
      // The point of an allowlist: a route added later is closed until someone
      // deliberately opens it, backed by a public Firestore rule.
      expect(RouterNotifier.isGuestAllowed('/some/route/added/later'), isFalse);
    });
  });

  group('isGuestAllowed is not fooled by lookalike prefixes', () {
    test('a sibling path that merely starts with /service stays private', () {
      // `startsWith('/service')` instead of `startsWith('/service/')` would
      // open both of these.
      expect(RouterNotifier.isGuestAllowed('/services-secret'), isFalse);
      expect(RouterNotifier.isGuestAllowed('/serviceX'), isFalse);
    });

    test('the bare /service collection is not a service detail', () {
      expect(RouterNotifier.isGuestAllowed('/service'), isFalse);
    });

    test('a sibling of /provider-profile stays private', () {
      expect(
        RouterNotifier.isGuestAllowed('/provider-profile-secret'),
        isFalse,
      );
      expect(RouterNotifier.isGuestAllowed('/provider-profile'), isFalse);
    });

    test('my own reviews are mine, not the public /reviews/:uid page', () {
      // /my-reviews does not start with /reviews/, and must not: it is the
      // signed-in author's view, including reviews hidden from the public page.
      expect(RouterNotifier.isGuestAllowed(AppRoutes.myReviews), isFalse);
      expect(RouterNotifier.isGuestAllowed('/reviews'), isFalse);
    });

    test('the allowlist anchors at the start of the path', () {
      // A route that merely CONTAINS an allowed segment is not allowed.
      expect(
        RouterNotifier.isGuestAllowed('/provider/inbox/service/svc_1'),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // signInWithReturnTo: the gate carries the intention
  // -------------------------------------------------------------------------
  group('signInWithReturnTo carries where the visitor was going', () {
    test('a gated path becomes the redirect parameter', () {
      final target = RouterNotifier.signInWithReturnTo(
        Uri.parse(AppRoutes.bookings),
      );
      expect(
        Uri.parse(target).path,
        AppRoutes.signIn,
        reason: 'the visitor must land on sign-in',
      );
      expect(Uri.parse(target).queryParameters['redirect'], AppRoutes.bookings);
    });

    test("a deep link's own query survives the round trip", () {
      // /service/:id?book=1 means "reopen the booking sheet". Dropping the
      // query would strand the visitor on the service page after signing in,
      // which is the bug this whole redirect dance exists to avoid.
      final target = RouterNotifier.signInWithReturnTo(
        Uri.parse('/service/svc_1?book=1'),
      );
      expect(
        Uri.parse(target).queryParameters['redirect'],
        '/service/svc_1?book=1',
      );
    });

    test('a multi-parameter query survives whole', () {
      final target = RouterNotifier.signInWithReturnTo(
        Uri.parse('/reviews/user_1?as=provider&from=push'),
      );
      expect(
        Uri.parse(target).queryParameters['redirect'],
        '/reviews/user_1?as=provider&from=push',
      );
    });

    test('the redirect parameter is percent-encoded, not spliced in raw', () {
      // The nested path and its `?`/`=` must not be readable as the OUTER
      // query, or a crafted target could inject parameters into sign-in.
      final target = RouterNotifier.signInWithReturnTo(
        Uri.parse('/service/svc_1?book=1'),
      );
      expect(
        target,
        '${AppRoutes.signIn}?redirect=%2Fservice%2Fsvc_1%3Fbook%3D1',
      );
      expect(
        Uri.parse(target).queryParameters.keys,
        ['redirect'],
        reason: 'the nested query must not become a sibling parameter',
      );
    });

    test('home needs no return trip and yields a bare sign-in', () {
      expect(
        RouterNotifier.signInWithReturnTo(Uri.parse(AppRoutes.home)),
        AppRoutes.signIn,
      );
    });

    test('an empty path yields a bare sign-in', () {
      // Nothing to resume: an empty `?redirect=` would be noise in the URL and
      // dead weight in postAuthTarget.
      expect(
        RouterNotifier.signInWithReturnTo(Uri.parse('')),
        AppRoutes.signIn,
      );
    });

    test('what the gate writes is what the guard reads back', () {
      // Round trip through the real pair: encode with signInWithReturnTo,
      // decode with postAuthTarget. An encoding change on one side that the
      // other side cannot read fails here rather than in production.
      const intention = '/service/svc_1?book=1';
      final signIn = RouterNotifier.signInWithReturnTo(Uri.parse(intention));
      expect(RouterNotifier.postAuthTarget(Uri.parse(signIn)), intention);
    });
  });

  // -------------------------------------------------------------------------
  // postAuthTarget: the anti-open-redirect guard
  // -------------------------------------------------------------------------
  group('postAuthTarget resumes the intention', () {
    test('an internal path is honoured', () {
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2Fbookings'),
        ),
        AppRoutes.bookings,
      );
    });

    test('an internal path keeps its own query', () {
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse(
            '${AppRoutes.signIn}?redirect=%2Fservice%2Fsvc_1%3Fbook%3D1',
          ),
        ),
        '/service/svc_1?book=1',
      );
    });

    test('no redirect parameter means nothing to resume', () {
      expect(
        RouterNotifier.postAuthTarget(Uri.parse(AppRoutes.signIn)),
        isNull,
      );
    });

    test('an empty redirect parameter means nothing to resume', () {
      // '' fails startsWith('/'), so it must not become a navigation to ''.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect='),
        ),
        isNull,
      );
    });

    test('other parameters on the sign-in URL are ignored', () {
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?from=push&utm=x'),
        ),
        isNull,
      );
    });
  });

  group('postAuthTarget refuses to send the visitor off-site', () {
    test('a protocol-relative target is rejected', () {
      // THE web trap: on a browser `//evil.example` inherits the current scheme
      // and is an absolute URL to someone else's host, while passing any naive
      // "starts with a slash, so it is internal" check.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2F%2Fevil.example'),
        ),
        isNull,
      );
    });

    test('a percent-encoded protocol-relative target is rejected', () {
      // Uri.queryParameters decodes before the guard sees the value, so
      // %2F%2F, its lowercase form and a literal // are the same attack.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2f%2fevil.example%2Fpath'),
        ),
        isNull,
      );
    });

    test('a single slash followed by an encoded slash is rejected', () {
      // A literal slash then an encoded one decodes to //evil.example: the same
      // protocol-relative URL, smuggled past a check that ran before decoding.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=/%2Fevil.example'),
        ),
        isNull,
      );
    });

    test('an absolute https URL is rejected', () {
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=https%3A%2F%2Fevil.example'),
        ),
        isNull,
      );
    });

    test('a scheme with no authority is rejected', () {
      // javascript: and mailto: never start with a slash, which is exactly why
      // the guard requires one.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=javascript%3Aalert(1)'),
        ),
        isNull,
      );
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=mailto%3Aa%40b.c'),
        ),
        isNull,
      );
    });

    test('a relative path with no leading slash is rejected', () {
      // 'bookings' or '../admin' resolve against wherever the visitor happens
      // to be, so the landing screen would depend on the previous URL.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=bookings'),
        ),
        isNull,
      );
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=..%2Fadmin'),
        ),
        isNull,
      );
    });

    test('a bare double slash is rejected', () {
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2F%2F'),
        ),
        isNull,
      );
    });

    test('a backslash-leading target is rejected', () {
      // A target whose first character is a backslash and not a slash fails the
      // leading-slash requirement, so it never reaches the // check.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%5C%5Cevil.example'),
        ),
        isNull,
      );
    });

    // ---- The two spellings a browser rewrites before it parses ----
    //
    // Both used to walk through the guard: it compared the raw string while the
    // browser had already folded it. postAuthTarget now normalises first, so
    // these two are the same attack as `a protocol-relative target is rejected`
    // above, written the way an attacker would write it.

    test('a slash-backslash target is rejected', () {
      // Per the WHATWG URL spec a browser treats a backslash as a slash in a
      // special-scheme URL, so /\evil.example parses as //evil.example: the
      // very protocol-relative URL the tests above reject. The percent-encoded
      // %5C form is identical, since queryParameters decodes before the guard.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2F%5Cevil.example'),
        ),
        isNull,
      );
    });

    test('a target with a control character before the second slash is '
        'rejected', () {
      // Browsers strip tab, LF and CR from a URL before parsing it, so
      // /<tab>/evil.example becomes //evil.example. Same bypass class as the
      // backslash: the guard compares a string, the browser compares another.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2F%09%2Fevil.example'),
        ),
        isNull,
      );
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2F%0A%2Fevil.example'),
        ),
        isNull,
      );
    });

    test('the backslash fold does not depend on where the backslash sits', () {
      // Every arrangement of slash and backslash that a browser resolves to
      // //evil.example. Folding before the decision covers them all at once;
      // enumerating them in the guard would have missed one.
      for (final target in <String>[
        '%5C%2Fevil.example', // \/evil.example
        '%5C%5Cevil.example', // \\evil.example
        '%2F%5C%5Cevil.example', // /\\evil.example
        '%2F%5C%2Fevil.example', // /\/evil.example
        '%2F%5cevil.example', // lowercase escape, same character
      ]) {
        expect(
          RouterNotifier.postAuthTarget(
            Uri.parse('${AppRoutes.signIn}?redirect=$target'),
          ),
          isNull,
          reason: '$target reaches the browser as //evil.example',
        );
      }
    });

    test('every character a browser strips is stripped before the check', () {
      // The strip set is a set, not one character: CR alone, CRLF, a repeated
      // tab, and a control character sitting BEFORE the leading slash all end
      // up as //evil.example once the browser has removed them.
      for (final target in <String>[
        '%2F%0D%2Fevil.example', // /<CR>/evil.example
        '%2F%0D%0A%2Fevil.example', // /<CR><LF>/evil.example
        '%2F%09%09%2Fevil.example', // /<TAB><TAB>/evil.example
        '%09%2F%2Fevil.example', // <TAB>//evil.example
        '%0D%0A%2F%2Fevil.example', // <CR><LF>//evil.example
      ]) {
        expect(
          RouterNotifier.postAuthTarget(
            Uri.parse('${AppRoutes.signIn}?redirect=$target'),
          ),
          isNull,
          reason: '$target reaches the browser as //evil.example',
        );
      }
    });

    test('the two rewrites combined are still one attack', () {
      // A stripped character and a folded one in the same target: handling one
      // family and not the other would let this through.
      for (final target in <String>[
        '%2F%09%5Cevil.example', // /<TAB>\evil.example
        '%2F%5C%09evil.example', // /\<TAB>evil.example
      ]) {
        expect(
          RouterNotifier.postAuthTarget(
            Uri.parse('${AppRoutes.signIn}?redirect=$target'),
          ),
          isNull,
          reason: '$target reaches the browser as //evil.example',
        );
      }
    });

    test('what is returned is the target that was judged', () {
      // An accepted target comes back normalised, never in the spelling that
      // arrived: returning the raw string would approve a value on one form of
      // itself and hand the router another, and would send native (which folds
      // nothing) and web (which folds everything) to two different places.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2Fservice%2Fsvc%5C1'),
        ),
        '/service/svc/1',
      );
    });

    test('the strip set is exactly the one a browser applies', () {
      // Vertical tab, form feed, space and NUL are NOT removed by the WHATWG
      // parser: they are percent-encoded inside the path, so the host stays
      // ours and these targets are internal, however ugly. Stripping them too
      // would be guessing at the spec rather than following it, so the guard
      // keeps them and this test says so out loud.
      for (final target in <String>[
        '%2F%0B%2Fevil.example', // vertical tab
        '%2F%0C%2Fevil.example', // form feed
        '%2F%20%2Fevil.example', // space
        '%2F%00%2Fevil.example', // NUL
      ]) {
        final resolved = RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=$target'),
        );
        expect(
          resolved,
          isNotNull,
          reason: '$target stays on our host, so it is not this guard\'s job',
        );
        expect(
          resolved!.startsWith('//'),
          isFalse,
          reason: 'whatever comes back must still be a single-slash path',
        );
      }
    });

    test('a percent-encoded backslash stays encoded and stays internal', () {
      // Double encoding: %255C arrives as the three characters %5C, which a
      // browser leaves percent-encoded in the path instead of decoding to a
      // backslash. So it is a path segment on our host, not a fold, and the
      // guard has nothing to reject.
      expect(
        RouterNotifier.postAuthTarget(
          Uri.parse('${AppRoutes.signIn}?redirect=%2F%255Cevil.example'),
        ),
        '/%5Cevil.example',
      );
    });
  });
}
