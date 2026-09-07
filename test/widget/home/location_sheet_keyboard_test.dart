// The home location sheet under the keyboard.
//
// This sheet opens from a StatefulShellRoute branch, so it is mounted here
// through shellLike(): an outer Scaffold with a bottom bar whose body hosts
// the nearest Navigator. Inside that body the sheet reads no keyboard inset
// at all; what bounds it is the body itself, shrunk by the keyboard. Before
// the fix the sheet was a non-scrollable DraggableScrollableSheet: the
// suggestions the user was typing towards sat under the keyboard, or the
// column overflowed the shrunk body.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/auth/auth_notifier.dart';
import 'package:outalma_app/src/application/auth/auth_providers.dart';
import 'package:outalma_app/src/application/auth/auth_state.dart';
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

const _suggestions = [
  PlaceSuggestion(placeId: 'p1', description: 'Dakar, Senegal'),
  PlaceSuggestion(placeId: 'p2', description: 'Dakar Plateau, Senegal'),
  PlaceSuggestion(placeId: 'p3', description: 'Dakar Yoff, Senegal'),
];

Widget _wrap({
  required GeocodingService geocoding,
  required ValueNotifier<double> keyboard,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
    activeModeProvider.overrideWith((_) => ActiveMode.client),
    serviceListProvider.overrideWith((_) => Stream.value(const [])),
    geocodingServiceProvider.overrideWithValue(geocoding),
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'typing an address keeps the suggestions and the actions above the keyboard',
    (tester) async {
      useSurface(tester, kReferenceSurface);
      final geocoding = _MockGeocodingService();
      when(
        () => geocoding.autocomplete(any()),
      ).thenAnswer((_) async => _suggestions);
      when(
        () => geocoding.getPlaceLatLng(any()),
      ).thenAnswer((_) async => (lat: 14.69, lng: -17.44, countryCode: 'SN'));
      final keyboard = ValueNotifier<double>(0);

      await tester.pumpWidget(_wrap(geocoding: geocoding, keyboard: keyboard));
      await tester.pump();

      // The location pill in the app bar opens the sheet.
      await tester.tap(find.text('Tout le Sénégal'));
      await tester.pumpAndSettle();
      // Home search bar + sheet field: the sheet's one is the last.
      final sheetField = find.byType(TextField).last;

      keyboard.value = kReferenceKeyboard;
      await tester.pumpAndSettle();
      await tester.enterText(sheetField, 'Dak');
      await tester.pumpAndSettle();

      expectAboveKeyboard(tester, sheetField, inset: kReferenceKeyboard);
      expectAboveKeyboard(
        tester,
        find.text('Dakar, Senegal'),
        inset: kReferenceKeyboard,
      );
      // The LAST suggestion too: the list is no longer capped at 160 px,
      // which used to clip the fifth prediction with nothing to scroll.
      final sheetScroll = find.byType(SingleChildScrollView).last;
      // Its own Scrollable comes first in tree order, before the nested lists.
      final sheetScrollable = find
          .descendant(of: sheetScroll, matching: find.byType(Scrollable))
          .first;
      final last = find.text('Dakar Yoff, Senegal');
      await tester.scrollUntilVisible(last, 100, scrollable: sheetScrollable);
      await tester.pumpAndSettle();
      expectAboveKeyboard(tester, last, inset: kReferenceKeyboard);

      // The actions below the suggestions are one drag away, not lost: drag
      // the sheet's scroll view, then the "whole country" button is visible
      // above the keyboard.
      final allAreas = find.widgetWithText(OutlinedButton, 'Tout le Sénégal');
      expect(allAreas, findsOneWidget);
      await tester.drag(sheetScroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      expectAboveKeyboard(tester, allAreas, inset: kReferenceKeyboard);

      // Picking a suggestion applies the filter: the radius slider and the
      // validate button appear, and both are reachable above the keyboard.
      await tester.drag(sheetScroll, const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dakar, Senegal'));
      await tester.pumpAndSettle();
      final validate = find.widgetWithText(ElevatedButton, 'Valider');
      await tester.scrollUntilVisible(
        validate,
        100,
        scrollable: sheetScrollable,
      );
      await tester.pumpAndSettle();
      expectAboveKeyboard(
        tester,
        find.byType(Slider),
        inset: kReferenceKeyboard,
      );
      expectAboveKeyboard(tester, validate, inset: kReferenceKeyboard);
    },
  );
}
