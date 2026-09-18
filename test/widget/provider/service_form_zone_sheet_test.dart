// The add-zone sheet of ServiceFormPage under the keyboard.
//
// The sheet's address field takes focus on open, so the keyboard is up from
// the first frame. Before the fix the sheet was a non-scrollable column: from
// two suggestions up, the radius slider and the validate button overflowed
// under the keyboard with nothing to scroll. Harness copied from
// service_form_focus_test.dart (edit mode is mandatory: create mode touches
// Firestore in initState).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/core/utils/debouncer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/pricing/pricing_providers.dart';
import 'package:outalma_app/src/data/services/geocoding_service.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/pricing/pricing_config.dart';
import 'package:outalma_app/src/features/provider/service_form_page.dart';

import '../../helpers/keyboard.dart';

class _MockGeocodingService extends Mock implements GeocodingService {}

PricingConfig _config() => const PricingConfig(
  version: 1,
  currency: 'XOF',
  boundedCategories: ['menage', 'cuisine', 'gardeEnfants', 'repassage'],
  maxExtraTasks: 3,
  modes: {
    PriceType.hourly: PricingModeBounds(
      min: 1000,
      max: 3500,
      extraBonusPercent: 25,
    ),
    PriceType.daily: PricingModeBounds(
      min: 2000,
      max: 10000,
      extraBonusPercent: 25,
    ),
    PriceType.monthly: PricingModeBounds(
      min: 50000,
      max: 150000,
      extraBonusPercent: 0,
      isRange: true,
    ),
  },
);

Service _existing() {
  final now = DateTime(2026, 1, 1);
  return Service(
    id: 's1',
    providerId: 'p1',
    categoryId: CategoryId.menage,
    title: 'Existing',
    photos: const [],
    priceType: PriceType.hourly,
    price: 2000,
    published: false,
    serviceZones: const [
      ServiceZone(label: 'Dakar', latitude: 0, longitude: 0, radiusKm: 10),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

final _suggestions = List.generate(
  5,
  (i) => PlaceSuggestion(placeId: 'p$i', description: 'Dakar zone $i'),
);

Future<void> _pump(
  WidgetTester tester, {
  required GeocodingService geocoding,
  required ValueNotifier<double> keyboard,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pricingConfigProvider.overrideWith((ref) => _config()),
        geocodingServiceProvider.overrideWithValue(geocoding),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: keyboardInsetBuilder(keyboard),
        home: ServiceFormPage(existing: _existing()),
      ),
    ),
  );
  await tester.pump();
}

/// Crosses the address autocomplete debounce.
///
/// A pending Timer schedules no frame, so `pumpAndSettle()` alone never reaches
/// it: without this the query never leaves the widget and the suggestion
/// assertions below pass or fail for the wrong reason.
Future<void> _settleAddressDebounce(WidgetTester tester) async {
  await tester.pump(kAddressSearchDebounce + const Duration(milliseconds: 50));
  await tester.pump();
}

void main() {
  testWidgets(
    'suggestions stay above the keyboard, picking one closes it and brings '
    'the validate button back',
    (tester) async {
      useSurface(tester, kReferenceSurface);
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.autocomplete(any()),
      ).thenAnswer((_) async => _suggestions);
      final keyboard = ValueNotifier<double>(0);
      await _pump(tester, geocoding: geocoding, keyboard: keyboard);

      // The add-zone control sits down the form on a small phone.
      final addZone = find.widgetWithText(OutlinedButton, 'Ajouter une zone');
      await tester.scrollUntilVisible(
        addZone,
        200,
        // The form ListView is the outermost scrollable of the page.
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addZone);
      await tester.pumpAndSettle();

      // Autofocus: the keyboard is up from the first frame of the sheet.
      expect(tester.testTextInput.hasAnyClients, isTrue);
      keyboard.value = kReferenceKeyboard;
      await tester.pumpAndSettle();

      final sheetField = find.byType(TextFormField).last;
      await tester.enterText(sheetField, 'Dak');
      await _settleAddressDebounce(tester);
      await tester.pumpAndSettle();

      // No overflow was thrown (it would have failed the test).
      expectAboveKeyboard(tester, sheetField, inset: kReferenceKeyboard);
      expectAboveKeyboard(
        tester,
        find.text('Dakar zone 0'),
        inset: kReferenceKeyboard,
      );
      // The LAST suggestion too: the list is no longer capped at 180 px,
      // which used to clip the fifth prediction with nothing to scroll.
      final last = find.text('Dakar zone 4');
      expectInsideBox(
        tester,
        last,
        find.ancestor(of: last, matching: find.byType(ListView)).first,
      );
      // The sheet's own scroll view, not the inner NeverScrollable list.
      final sheetScrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(last, 100, scrollable: sheetScrollable);
      await tester.pumpAndSettle();
      expectAboveKeyboard(tester, last, inset: kReferenceKeyboard);
      await tester.drag(sheetScrollable, const Offset(0, 400));
      await tester.pumpAndSettle();
      final validate = find.widgetWithText(ElevatedButton, 'Valider');
      expect(validate, findsOneWidget);
      // The drag itself closed the keyboard (dismiss on drag): refocus the
      // field so the assertion below is about the pick, not about the drag.
      await tester.tap(sheetField);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      // Picking a suggestion drops focus, i.e. closes the keyboard...
      await tester.tap(find.text('Dakar zone 0'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isFalse);
      keyboard.value = 0;
      await tester.pumpAndSettle();

      // ...and the radius slider and the validate button are on screen.
      expect(find.byType(Slider), findsOneWidget);
      expectAboveKeyboard(tester, validate, inset: 0);
      expectAboveKeyboard(tester, find.byType(Slider), inset: 0);
    },
  );

  // -------------------------------------------------------------------------
  // The zone address field must query Places ONCE per typed address, when the
  // user stops typing, and must never reopen the suggestion list on top of a
  // choice already made. The sequences below are deliberate: a test that lets
  // the delay elapse BEFORE the choice has nothing left to cancel and would
  // pass with the guard removed.
  // -------------------------------------------------------------------------
  group('address autocomplete debounce', () {
    // The second entry: always built, unlike the last which needs a
    // scrollUntilVisible, so asserting its absence cannot be vacuously true.
    const otherSuggestion = 'Dakar zone 1';

    Future<Finder> openZoneSheet(
      WidgetTester tester,
      GeocodingService geocoding,
    ) async {
      await _pump(
        tester,
        geocoding: geocoding,
        keyboard: ValueNotifier<double>(0),
      );
      final addZone = find.widgetWithText(OutlinedButton, 'Ajouter une zone');
      await tester.scrollUntilVisible(
        addZone,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addZone);
      await tester.pumpAndSettle();
      return find.byType(TextFormField).last;
    }

    testWidgets('a burst of keystrokes queries Places once, with the last '
        'text', (tester) async {
      useSurface(tester, kReferenceSurface);
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.autocomplete(any()),
      ).thenAnswer((_) async => _suggestions);
      final field = await openZoneSheet(tester, geocoding);

      // Cumulative: enterText REPLACES the content, so literal single letters
      // would never reach the minimum length and nothing would fire.
      for (final text in ['D', 'Da', 'Dak', 'Daka', 'Dakar']) {
        await tester.enterText(field, text);
      }
      await _settleAddressDebounce(tester);

      // Captured, not verified against a literal: verify(autocomplete('Dakar'))
      // only counts the invocations that MATCH, so it would stay green while
      // the intermediate calls also went out.
      final captured = verify(
        () => geocoding.autocomplete(captureAny()),
      ).captured;
      expect(captured, ['Dakar']);
    });

    testWidgets('nothing is queried before the user stops typing', (
      tester,
    ) async {
      useSurface(tester, kReferenceSurface);
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.autocomplete(any()),
      ).thenAnswer((_) async => _suggestions);
      final field = await openZoneSheet(tester, geocoding);

      await tester.enterText(field, 'Dakar');
      await tester.pump(const Duration(milliseconds: 175)); // half the delay

      verifyNever(() => geocoding.autocomplete(any()));
    });

    testWidgets('picking a suggestion does not let the list reopen on top of '
        'it', (tester) async {
      useSurface(tester, kReferenceSurface);
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.autocomplete(any()),
      ).thenAnswer((_) async => _suggestions);
      final field = await openZoneSheet(tester, geocoding);

      await tester.enterText(field, 'Dakar');
      await _settleAddressDebounce(tester);
      expect(find.text(otherSuggestion), findsOneWidget);

      // One more keystroke RE-ARMS the timer while the previous list is still
      // on screen: the choice below happens with a query in flight.
      await tester.enterText(field, 'Dakar z');
      await tester.tap(find.text('Dakar zone 0'));
      await tester.pumpAndSettle();

      await _settleAddressDebounce(tester);

      expect(
        find.text(otherSuggestion),
        findsNothing,
        reason: 'the in-flight query was cancelled when the user chose',
      );
    });

    testWidgets('closing the sheet drops the pending query', (tester) async {
      useSurface(tester, kReferenceSurface);
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.autocomplete(any()),
      ).thenAnswer((_) async => _suggestions);
      final field = await openZoneSheet(tester, geocoding);

      await tester.enterText(field, 'Dakar');
      // Tear the tree down with the delay still pending, and do NOT advance
      // the clock: the binding's own end-of-test check ("A Timer is still
      // pending even after the widget tree was disposed") IS the assertion.
      //
      // Advancing the clock here instead would prove nothing on this screen:
      // _fetchSuggestions reads the provider off a disposed ConsumerState,
      // which throws, and the catch swallows it, so a verifyNever would stay
      // true whether dispose() cancelled or not. Verified by mutation.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
