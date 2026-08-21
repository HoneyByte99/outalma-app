// Widget tests for the encadre pricing section of ServiceFormPage.
//
// Covers, at the widget layer, the acceptance scenarios that do not need the
// server: the range is visible before input (SC-01), it tracks extra tasks
// (SC-05/06) and the mode (SC-11), out-of-range input is refused before send
// with a plain-language message (SC-02/03, SC-28/29), the extra-task cap is
// signalled (SC-08), and the grid-unavailable states disable publishing
// (SC-12). The form is pumped in EDIT mode so initState does not reach
// FirebaseFirestore.instance (create mode mints an id there).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/pricing/pricing_providers.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/pricing/pricing_config.dart';
import 'package:outalma_app/src/features/provider/service_form_page.dart';

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

Service _existing({
  CategoryId category = CategoryId.menage,
  PriceType priceType = PriceType.hourly,
  int price = 2000,
}) {
  final now = DateTime(2026, 1, 1);
  return Service(
    id: 's1',
    providerId: 'p1',
    categoryId: category,
    title: 'Existing',
    photos: const [],
    priceType: priceType,
    price: price,
    published: false,
    serviceZones: const [
      ServiceZone(label: 'Dakar', latitude: 0, longitude: 0, radiusKm: 10),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

String _plain(String s) =>
    s.replaceAll(RegExp('[\u00A0\u202F\u2009\u2007]'), ' ');

Future<void> _pump(
  WidgetTester tester, {
  required Override pricingOverride,
  Service? existing,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pricingOverride],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ServiceFormPage(existing: existing ?? _existing()),
      ),
    ),
  );
  await tester.pump();
}

// Finds a Text whose (space-normalised) content contains [needle].
Finder _textContaining(String needle) => find.byWidgetPredicate(
  (w) => w is Text && w.data != null && _plain(w.data!).contains(needle),
);

void main() {
  // A tall surface so the scrollable form renders most fields without scrolling.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1400, 3600);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Override dataOverride() =>
      pricingConfigProvider.overrideWith((ref) => _config());

  testWidgets('SC-01: hourly range visible before input', (tester) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();
    expect(_textContaining('1 000'), findsWidgets);
    expect(_textContaining('3 500'), findsWidgets);
    expect(_textContaining('F CFA'), findsWidgets);
  });

  testWidgets('SC-05/06: checking an extra task lifts the ceiling to 4 375', (
    tester,
  ) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();
    expect(_textContaining('4 375'), findsNothing);

    // The extra-task checkboxes (main is menage -> cuisine is the first one).
    final firstExtra = find.byType(Checkbox).first;
    await tester.ensureVisible(firstExtra);
    await tester.tap(firstExtra);
    await tester.pump();

    expect(_textContaining('4 375'), findsWidgets);
    // Floor is unchanged.
    expect(_textContaining('1 000'), findsWidgets);
  });

  testWidgets('SC-02/03: out-of-range price refused before send', (
    tester,
  ) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();

    final priceField = find.byType(TextFormField).at(2); // title, desc, price
    await tester.enterText(priceField, '999');
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // A plain-language range message, naming both bounds, no technical code.
    final err = _textContaining('compris entre');
    expect(err, findsOneWidget);
    final errText = _plain((tester.widget(err) as Text).data!);
    expect(errText, contains('1 000'));
    expect(errText, contains('3 500'));
    expect(errText, isNot(contains('price')));
    expect(errText, isNot(contains('null')));
  });

  testWidgets('SC-08: selecting the max extra tasks shows the limit note', (
    tester,
  ) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();

    // Check all three extra-task options (cuisine, gardeEnfants, repassage).
    for (var i = 0; i < 3; i++) {
      final box = find.byType(Checkbox).at(i);
      await tester.ensureVisible(box);
      await tester.tap(box);
      await tester.pump();
    }
    // maxExtraTasks reached -> the limit note is shown.
    expect(
      _textContaining('Trois tâches supplémentaires au maximum'),
      findsOneWidget,
    );
  });

  testWidgets('SC-11: switching to monthly shows a min/max range', (
    tester,
  ) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();

    final monthly = find.text('par mois');
    await tester.ensureVisible(monthly);
    await tester.tap(monthly);
    await tester.pumpAndSettle();

    expect(find.text('Minimum mensuel'), findsOneWidget);
    expect(find.text('Maximum mensuel'), findsOneWidget);
    expect(_textContaining('50 000'), findsWidgets);
    expect(_textContaining('150 000'), findsWidgets);
  });

  testWidgets('SC-28: a monthly bound outside 50 000..150 000 is refused', (
    tester,
  ) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();
    await tester.tap(find.text('par mois'));
    await tester.pumpAndSettle();

    // Fields after title, description: monthly min (2), monthly max (3).
    await tester.enterText(find.byType(TextFormField).at(2), '49999');
    await tester.enterText(find.byType(TextFormField).at(3), '100000');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    final err = _textContaining('compris entre');
    expect(err, findsWidgets);
  });

  testWidgets('SC-29: a monthly max below the min is refused', (tester) async {
    await _pump(tester, pricingOverride: dataOverride());
    await tester.pump();
    await tester.tap(find.text('par mois'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(2), '120000');
    await tester.enterText(find.byType(TextFormField).at(3), '80000');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(_textContaining('supérieur ou égal'), findsOneWidget);
  });

  testWidgets('SC-12 case A: grid loading disables publishing', (tester) async {
    final never = Completer<PricingConfig>();
    await _pump(
      tester,
      pricingOverride: pricingConfigProvider.overrideWith(
        (ref) => never.future,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'SC-12 case B/C: grid error shows retry and disables publishing',
    (tester) async {
      await _pump(
        tester,
        pricingOverride: pricingConfigProvider.overrideWith(
          (ref) => Future<PricingConfig>.error(StateError('missing')),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(_textContaining('tarifaire'), findsWidgets);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    },
  );
}
