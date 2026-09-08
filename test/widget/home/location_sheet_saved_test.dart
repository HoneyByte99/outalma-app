// The home location sheet with a filter already applied.
//
// The keyboard test next door covers the typing path. This one mounts the
// sheet in the state the user reaches after picking an address: radius
// slider and validate button, the star that opens the "name this address"
// dialog, and the saved addresses list. All of that used to live in an
// Expanded/Spacer column that the keyboard squeezed; it now sits in the
// scroll view and must stay reachable, one drag away, above the keyboard.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
import 'package:outalma_app/src/application/home/location_providers.dart';
import 'package:outalma_app/src/application/service/service_providers.dart';
import 'package:outalma_app/src/application/user/user_providers.dart';
import 'package:outalma_app/src/data/services/geocoding_service.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/keyboard.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
}

class _MockGeocodingService extends Mock implements GeocodingService {}

const _filter = LocationFilter(
  label: 'Dakar, Senegal',
  lat: 14.69,
  lng: -17.44,
  radiusKm: 30,
);

const _savedHome = {
  'label': 'Maison',
  'address': 'Dakar Plateau, Senegal',
  'lat': 14.67,
  'lng': -17.43,
  'radiusKm': 20,
};

Widget _wrap({
  required GeocodingService geocoding,
  required ValueNotifier<double> keyboard,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    serviceListProvider.overrideWith((_) => Stream.value(const [])),
    geocodingServiceProvider.overrideWithValue(geocoding),
    locationFilterProvider.overrideWith((_) => _filter),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fr'),
    builder: keyboardInsetBuilder(keyboard),
    home: shellLike(const HomePage()),
  ),
);

Future<void> _openSheet(
  WidgetTester tester,
  ValueNotifier<double> keyboard,
) async {
  useSurface(tester, kReferenceSurface);
  await tester.pumpWidget(
    _wrap(geocoding: _MockGeocodingService(), keyboard: keyboard),
  );
  await tester.pump();
  // The app bar pill (label plus radius) opens the sheet.
  await tester.tap(find.text('Dakar, Senegal, 30 km'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'saved_locations': jsonEncode([_savedHome]),
    }),
  );

  testWidgets(
    'with a filter applied, radius, validate and saved addresses are all '
    'reachable above the keyboard',
    (tester) async {
      final keyboard = ValueNotifier<double>(0);
      await _openSheet(tester, keyboard);

      // The state reached after picking an address.
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('30 km'), findsOneWidget);
      final validate = find.widgetWithText(ElevatedButton, 'Valider');
      expect(validate, findsOneWidget);
      expect(find.text('Mes adresses'), findsOneWidget);
      expect(find.text('Maison'), findsOneWidget);

      keyboard.value = kReferenceKeyboard;
      await tester.pumpAndSettle();
      // No overflow was thrown; the saved addresses sit at the bottom of the
      // scroll view and come up on a drag, above the keyboard.
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expectAboveKeyboard(
        tester,
        find.text('Maison'),
        inset: kReferenceKeyboard,
      );
      keyboard.value = 0;
      await tester.pumpAndSettle();

      // Sliding the radius updates the label; validate closes the sheet.
      await tester.drag(find.byType(Slider), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(find.text('30 km'), findsNothing);
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
    },
  );

  testWidgets('the star opens a dialog that names and saves the address', (
    tester,
  ) async {
    await _openSheet(tester, ValueNotifier<double>(0));

    await tester.tap(find.byTooltip('Enregistrer cette adresse'));
    await tester.pumpAndSettle();
    expect(find.text("Nom de l'adresse"), findsOneWidget);
    final save = find.widgetWithText(ElevatedButton, 'Enregistrer');

    // An empty name is ignored: the dialog stays.
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text("Nom de l'adresse"), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Bureau');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text("Nom de l'adresse"), findsNothing);
    expect(find.text('"Bureau" enregistré'), findsOneWidget);
    // The new address joins the list in the sheet.
    expect(find.text('Bureau'), findsWidgets);

    // Cancel path of the dialog.
    await tester.tap(find.byTooltip('Enregistrer cette adresse'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();
    expect(find.text("Nom de l'adresse"), findsNothing);
  });

  testWidgets(
    'a saved address applies on tap and the clear icon drops the filter',
    (tester) async {
      await _openSheet(tester, ValueNotifier<double>(0));

      await tester.tap(find.text('Maison'));
      await tester.pumpAndSettle();
      // The sheet closed and the pill now carries the favourite's address.
      expect(find.byType(Slider), findsNothing);
      final pill = find.text('Dakar Plateau, Senegal, 20 km');
      expect(pill, findsOneWidget);

      await tester.tap(pill);
      await tester.pumpAndSettle();
      // Removing the favourite from the list.
      final sheetTile = find.widgetWithText(InkWell, 'Maison');
      expect(sheetTile, findsOneWidget);
      await tester.tap(
        find.descendant(of: sheetTile, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Maison'), findsNothing);

      // The clear icon in the field drops the filter and closes the sheet.
      await tester.tap(
        find.descendant(
          of: find.byType(TextField).last,
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Tout le Sénégal'), findsWidgets);
    },
  );
}
