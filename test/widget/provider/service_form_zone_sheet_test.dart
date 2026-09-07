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
      await tester.scrollUntilVisible(
        last,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expectAboveKeyboard(tester, last, inset: kReferenceKeyboard);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 400));
      await tester.pumpAndSettle();
      final validate = find.widgetWithText(ElevatedButton, 'Valider');
      expect(validate, findsOneWidget);

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
}
