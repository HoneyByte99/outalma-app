import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/features/review/rating_summary.dart';

/// The reviews screen is opened for a CLIENT from a booking and for a PROVIDER
/// from a listing, and it cannot tell them apart on its own. Reading the wrong
/// source shows "Nouveau" for every client for ever on one side, or a
/// floorless average on the other. So the route carries the answer.
///
/// It calls the router's OWN parser on the strings its OWN builder produces,
/// so inverting the parser fails here. It does NOT drive the GoRoute builder
/// itself: that wiring is covered by the page test, not by this one.

void main() {
  group('the reviews route carries which reputation it shows', () {
    test('a provider link asks for the aggregate', () {
      final path = AppRoutes.userReviews('prov_1', asProvider: true);
      expect(path, '/reviews/prov_1?as=provider');
      expect(
        AppRoutes.ratingSourceFromQuery(Uri.parse(path).queryParameters['as']),
        RatingSource.provider,
      );
    });

    test('a client link asks for the review-derived reputation', () {
      final path = AppRoutes.userReviews('client_1', asProvider: false);
      expect(path, '/reviews/client_1?as=client');
      expect(
        AppRoutes.ratingSourceFromQuery(Uri.parse(path).queryParameters['as']),
        RatingSource.client,
      );
    });

    test('a link with no source falls back to the client reputation', () {
      // A pasted or legacy link. Falling back to the derived reputation is the
      // safe side: it is computed from reviews that exist, whereas the
      // aggregate would be absent and read as "Nouveau" for everyone.
      expect(
        AppRoutes.ratingSourceFromQuery(
          Uri.parse('/reviews/x').queryParameters['as'],
        ),
        RatingSource.client,
      );
    });

    test('the two links never produce the same path for the same uid', () {
      expect(
        AppRoutes.userReviews('u', asProvider: true),
        isNot(AppRoutes.userReviews('u', asProvider: false)),
      );
    });
  });
}
