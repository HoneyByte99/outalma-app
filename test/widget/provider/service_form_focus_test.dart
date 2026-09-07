// Widget test for the title -> description focus chain on the real
// ServiceFormPage (the "Nouveau service" screen from the brief): the title
// field's "next" action must land focus on the description field rather
// than falling through ambient traversal order, which would land on the
// (non-focusable) category selector instead.

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

import '../../helpers/keyboard.dart';

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

Future<void> _pump(
  WidgetTester tester, {
  ValueNotifier<double>? keyboard,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pricingConfigProvider.overrideWith((ref) => _config())],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: keyboard == null ? null : keyboardInsetBuilder(keyboard),
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

  // The save button used to live in a bottomNavigationBar, which the Scaffold
  // pins to the screen bottom BEHIND the keyboard: while the provider typed
  // the title, the button and its enabled state were out of sight. It now
  // sits in a footer inside the body, which shrinks with the keyboard.
  group('ServiceFormPage, save button under the keyboard', () {
    testWidgets('the save button stays visible while typing the title', (
      tester,
    ) async {
      useSurface(tester, kReferenceSurface);
      final keyboard = ValueNotifier<double>(0);
      await _pump(tester, keyboard: keyboard);

      final saveButton = find.byType(ElevatedButton);
      expect(saveButton, findsOneWidget);
      final restingTop = tester.getRect(saveButton).top;

      await tester.tap(find.byType(TextFormField).first);
      keyboard.value = kReferenceKeyboard;
      await tester.pumpAndSettle();

      expectAboveKeyboard(tester, saveButton, inset: kReferenceKeyboard);
      expect(tester.getRect(saveButton).top, lessThan(restingTop));
    });
  });
}
