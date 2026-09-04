// Widget tests for the keyboard-dismiss-bar visibility condition and the
// title -> description focus chain on the real ServiceFormPage (the
// "Nouveau service" screen from the brief).
//
// KeyboardDismissBar itself is unit-tested against synthetic fields in
// keyboard_dismiss_bar_test.dart; these tests instead prove the three
// families on the production widgets that motivated the change: the title
// field (single line, self-dismissing) no longer shows the bar, the price
// field (numeric, no return key on iOS) and the description field
// (multiline, return inserts a newline) always do, and the title's "next"
// action lands focus on the description field.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/app/keyboard_dismiss_bar.dart';
import 'package:outalma_app/src/application/pricing/pricing_providers.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/pricing/pricing_config.dart';
import 'package:outalma_app/src/features/provider/service_form_page.dart';

const _barKey = Key('keyboardDismissBar');

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

// Mirrors the production wiring (app.dart's MaterialApp.builder wraps the
// Navigator in KeyboardDismissBar via ConnectivityBanner) so the bar's
// visibility condition is exercised the same way it runs for real.
Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pricingConfigProvider.overrideWith((ref) => _config())],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            KeyboardDismissBar(child: child ?? const SizedBox.shrink()),
        home: ServiceFormPage(existing: _existing()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // A tall surface so the scrollable form renders every field without
  // scrolling, same as service_form_pricing_test.dart.
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

  group('ServiceFormPage, the dismiss bar follows the field family', () {
    testWidgets(
      'family 1 (single line, text keyboard): the title field no longer '
      'shows the bar',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.byType(TextFormField).first); // title
        await tester.pumpAndSettle();

        expect(find.byKey(_barKey), findsNothing);
      },
    );

    testWidgets('family 2 (numeric): the price field always shows the bar', (
      tester,
    ) async {
      await _pump(tester);

      // Fields in order: title, description, price (hourly, not monthly).
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();

      expect(find.byKey(_barKey), findsOneWidget);
    });

    testWidgets(
      'family 3 (multiline): the description field always shows the bar',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.byType(TextFormField).at(1)); // description
        await tester.pumpAndSettle();

        expect(find.byKey(_barKey), findsOneWidget);
      },
    );
  });

  group('ServiceFormPage, focus chaining', () {
    testWidgets(
      'pressing next on the title field moves focus to the description '
      'field',
      (tester) async {
        await _pump(tester);

        final titleField = find.byType(TextFormField).first;
        await tester.tap(titleField);
        await tester.enterText(titleField, 'Ménage à domicile');
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();

        final descriptionEditable = tester.widget<EditableText>(
          find.descendant(
            of: find.byType(TextFormField).at(1),
            matching: find.byType(EditableText),
          ),
        );
        expect(descriptionEditable.focusNode.hasFocus, isTrue);
      },
    );
  });
}
