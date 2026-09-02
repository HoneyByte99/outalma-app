// The location line of a catalogue card, at the width a real card actually has.
//
// service_location_label_test proves WHICH zone and WHICH distance the rule
// picks. It cannot prove that the client ever SEES the distance, because it
// compares strings and a string is never too narrow. This file pumps the card
// into one column of the two-column grid (163.5 px at 375 px of screen) with a
// zone name long enough to fill it, and asks the only question that matters
// there: of the two parts of that line, which one does the ellipsis eat?
//
// The answer has to be "the zone name". The distance is what makes a client
// choose between two cards; the zone name is context they usually just typed
// into the filter themselves. A single pre-assembled "<zone> · <km>" string in
// one ellipsed Text always answers the other way round, since the distance is
// the tail.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/home/location_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/public_profile.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/utils/distance.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

/// One column of the home grid on a 375 px phone, which is the narrowest real
/// case: `home_page.dart` builds 2 columns below 700 px, with 16 px of page
/// padding on each side and 16 px between them.
const _screenWidth = 375.0;
const _cardWidth = (_screenWidth - 16 * 2 - 16) / 2; // 163.5
const _cardHeight = _cardWidth + 151; // infoHeight, as the grid computes it

/// The zone the owner hit the defect on, spelled the way providers spell it.
/// Long, and mostly redundant with the filter the client just set.
const _longZone = ServiceZone(
  label: 'Dakar Grand Yoff Extension Front de Terre',
  latitude: 14.7300,
  longitude: -17.4600,
  radiusKm: 10,
);

const _rufisque = ServiceZone(
  label: 'Rufisque',
  latitude: 14.7167,
  longitude: -17.2667,
  radiusKm: 15,
);

/// The client's filter: Dakar Plateau, about 7 km from the zone above.
const _plateauFilter = LocationFilter(
  label: 'Dakar Plateau',
  lat: 14.6693,
  lng: -17.4381,
  radiusKm: 20,
);

Service _service(List<ServiceZone> zones) => Service(
  id: 'svc_1',
  providerId: 'p1',
  categoryId: CategoryId.menage,
  title: 'Menage complet appartement',
  photos: const [],
  priceType: PriceType.fixed,
  price: 5000,
  published: true,
  serviceZones: zones,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Every paragraph in the tree whose text contains [needle], with the render
/// object, because whether the ellipsis had to cut is a rendering fact and
/// only the render object knows it.
Iterable<RenderParagraph> _paragraphsWith(WidgetTester tester, String needle) =>
    tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .where((p) => p.text.toPlainText().contains(needle));

void main() {
  Widget wrap(Service service, {LocationFilter? filter}) => ProviderScope(
    overrides: [
      publicProfileByIdProvider('p1').overrideWith(
        (_) => Stream.value(
          const PublicProfile(id: 'p1', displayName: 'Moussa Diallo'),
        ),
      ),
      providerRatingProvider('p1').overrideWith((_) => const Stream.empty()),
      locationFilterProvider.overrideWith((_) => filter),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _cardWidth,
            height: _cardHeight,
            child: ServiceCard(service: service),
          ),
        ),
      ),
    ),
  );

  Future<void> pumpCard(
    WidgetTester tester,
    Service service, {
    LocationFilter? filter,
  }) async {
    await tester.pumpWidget(wrap(service, filter: filter));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the distance survives a zone name that fills the card', (
    tester,
  ) async {
    final km = formatDistanceKm(
      haversineKm(
        _longZone.latitude,
        _longZone.longitude,
        _plateauFilter.lat,
        _plateauFilter.lng,
      ),
    );
    // Pins the fixture: a filter sitting on the zone would make the needle
    // "0.0 km" and the test would prove nothing about a real distance.
    expect(km, '7.1');

    await pumpCard(tester, _service([_longZone]), filter: _plateauFilter);

    final withKm = _paragraphsWith(tester, '$km km');
    expect(
      withKm,
      isNotEmpty,
      reason: 'the distance left the render tree entirely',
    );
    for (final p in withKm) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason:
            'the distance sits in a paragraph the ellipsis had to cut, and it '
            'is the tail of that paragraph, so the distance is what got eaten: '
            '"${p.text.toPlainText()}"',
      );
    }

    // The zone name stays on the line as context. Ellipsed is fine, absent is
    // not: without it the client cannot tell 7 km from where.
    expect(_paragraphsWith(tester, 'Dakar Grand Yoff'), isNotEmpty);
  });

  testWidgets('the count of other zones survives it too', (tester) async {
    // No filter, so the line falls back to "<first zone> +N". The count is the
    // same kind of short decisive tail as the distance: dropping it lets a
    // client read one zone and conclude the provider covers nothing else.
    await pumpCard(tester, _service([_longZone, _rufisque]));

    final withCount = _paragraphsWith(tester, '+1');
    expect(withCount, isNotEmpty, reason: 'the +N count left the render tree');
    for (final p in withCount) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason:
            'the count is the tail of an ellipsed paragraph: '
            '"${p.text.toPlainText()}"',
      );
    }
  });

  testWidgets('a screen reader still gets the whole line, ellipsis or not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final km = formatDistanceKm(
      haversineKm(
        _longZone.latitude,
        _longZone.longitude,
        _plateauFilter.lat,
        _plateauFilter.lng,
      ),
    );

    await pumpCard(tester, _service([_longZone]), filter: _plateauFilter);

    // The card is one merged semantics node (it is a button), so the whole
    // card is looked up and the line has to appear inside it, unbroken:
    // splitting the display into two Texts must not split the announcement,
    // nor drop the part that is visually truncated.
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('${_longZone.label} · $km km')),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('no filter and a single zone: the zone alone, no stray marker', (
    tester,
  ) async {
    // The case with nothing to put after the name. The line must not grow an
    // empty tail, a separator or a "null".
    await pumpCard(tester, _service([_rufisque]));

    expect(find.text('Rufisque'), findsOneWidget);
    expect(_paragraphsWith(tester, 'km'), isEmpty);
    expect(_paragraphsWith(tester, '·'), isEmpty);
    expect(_paragraphsWith(tester, 'null'), isEmpty);
  });
}
