// The gender pictogram AS THE CATALOGUE CARD RENDERS IT.
//
// gender_icon_test proves the widget alone behaves. This proves the wiring: the
// card shows a SERVICE, the gender belongs to the PROVIDER, and the card
// resolves the provider through `publicProfileByIdProvider`, the same path it
// already uses for the name and the avatar. A projection that never carried the
// field would leave the icon silently absent on every card, and no test of the
// widget in isolation would notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/home/location_providers.dart';
import 'package:outalma_app/src/application/review/review_providers.dart';
import 'package:outalma_app/src/application/user/public_profile_providers.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/public_profile.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/features/home/home_page.dart';

final _service = Service(
  id: 'svc_1',
  providerId: 'p1',
  categoryId: CategoryId.menage,
  title: 'Menage complet appartement',
  photos: const [],
  priceType: PriceType.fixed,
  price: 5000,
  published: true,
  serviceZones: const [],
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  Widget wrap(PublicProfile? profile) => ProviderScope(
    overrides: [
      publicProfileByIdProvider(
        'p1',
      ).overrideWith((_) => Stream.value(profile)),
      providerRatingProvider('p1').overrideWith((_) => const Stream.empty()),
      locationFilterProvider.overrideWith((_) => null),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 180,
          height: 260,
          child: ServiceCard(service: _service),
        ),
      ),
    ),
  );

  Future<void> pumpCard(WidgetTester tester, PublicProfile? profile) async {
    await tester.pumpWidget(wrap(profile));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a provider who declared female gets the woman pictogram', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const PublicProfile(
        id: 'p1',
        displayName: 'Awa Cisse',
        gender: Gender.female,
      ),
    );

    expect(find.byIcon(Icons.woman), findsOneWidget);
    expect(find.byIcon(Icons.man), findsNothing);
    // Icon ALONE: the owner asked for no word on this surface, and the name
    // beside it has about forty pixels to live in.
    expect(find.text('Femme'), findsNothing);
  });

  testWidgets('a provider who declared male gets the man pictogram', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const PublicProfile(
        id: 'p1',
        displayName: 'Moussa Diallo',
        gender: Gender.male,
      ),
    );

    expect(find.byIcon(Icons.man), findsOneWidget);
    expect(find.byIcon(Icons.woman), findsNothing);
  });

  testWidgets('a provider with no declared gender gets NO pictogram', (
    tester,
  ) async {
    // The production case today: 50 accounts out of 50. A default glyph here
    // would assert a gender next to a real person's name on a card any visitor
    // can see, which is worse than saying nothing.
    await pumpCard(
      tester,
      const PublicProfile(id: 'p1', displayName: 'Moussa Diallo'),
    );

    expect(find.byIcon(Icons.man), findsNothing);
    expect(find.byIcon(Icons.woman), findsNothing);
    expect(find.text('Moussa Diallo'), findsOneWidget);
  });

  testWidgets('an unresolved provider read shows no pictogram either', (
    tester,
  ) async {
    // Same rule as the rating row: while the read is in flight the card claims
    // nothing. Guessing during the flight would flicker a glyph on every scroll.
    await pumpCard(tester, null);

    expect(find.byIcon(Icons.man), findsNothing);
    expect(find.byIcon(Icons.woman), findsNothing);
  });
}
