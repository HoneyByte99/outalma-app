// The rule behind the location line on a service card.
//
// The home grid already ran haversineKm between every zone and the active
// filter to DECIDE whether a card appears, then threw the number away. These
// tests pin down what is now displayed instead, and above all the two ways it
// could lie: a distance shown with no reference point, and a distance measured
// from a zone that was never located.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/models/service.dart';
import 'package:outalma_app/src/domain/models/service_zone.dart';
import 'package:outalma_app/src/domain/utils/distance.dart';
import 'package:outalma_app/src/features/shared/service_location_label.dart';

/// Dakar Plateau, and points at known distances from it.
const _plateau = ServiceZone(
  label: 'Dakar Plateau',
  latitude: 14.6693,
  longitude: -17.4381,
  radiusKm: 10,
);
const _rufisque = ServiceZone(
  label: 'Rufisque',
  latitude: 14.7167,
  longitude: -17.2667,
  radiusKm: 15,
);
const _pikine = ServiceZone(
  label: 'Pikine',
  latitude: 14.7548,
  longitude: -17.3901,
  radiusKm: 10,
);

/// A zone the provider named but whose position never resolved. (0, 0) is the
/// repo's marker for that, not a point in the Gulf of Guinea.
const _unlocated = ServiceZone(
  label: 'Saint-Louis',
  latitude: 0,
  longitude: 0,
  radiusKm: 20,
);

Service _service(List<ServiceZone> zones) => Service(
  id: 's1',
  providerId: 'p1',
  categoryId: CategoryId.menage,
  title: 'Menage complet',
  photos: const [],
  priceType: PriceType.hourly,
  price: 2500,
  published: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  serviceZones: zones,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  group('no location filter: the zone alone', () {
    test('a single zone shows its label and NO distance', () {
      final label = serviceLocationLabel(_service([_plateau]), l10n);
      expect(label, 'Dakar Plateau');
      expect(
        label,
        isNot(contains('km')),
        reason:
            'a distance with no reference point would read as "from you" '
            'while meaning "from the first zone in the list"',
      );
    });

    test('several zones show the first plus a count of the others', () {
      // Dropping the count would let a client read "Dakar Plateau" and
      // conclude the provider does not cover Rufisque, when they do.
      expect(
        serviceLocationLabel(_service([_plateau, _rufisque, _pikine]), l10n),
        'Dakar Plateau +2',
      );
    });

    test('a service with no zone at all returns null, not an empty line', () {
      expect(serviceLocationLabel(_service([]), l10n), isNull);
    });
  });

  group('with a location filter: the CLOSEST zone and its distance', () {
    test('a single zone shows its label and the distance', () {
      // Filter set on Dakar Plateau itself: same point, so under a kilometer.
      final label = serviceLocationLabel(
        _service([_plateau]),
        l10n,
        origin: (lat: 14.6693, lng: -17.4381),
      );
      expect(label, 'Dakar Plateau · 0.0 km');
    });

    test('multi-zone: the zone nearest the filter wins, not the first', () {
      // The filter sits ON Rufisque, which is listed LAST. Returning the first
      // zone would display a distance larger than the one that let this card
      // through the filter in the first place.
      final label = serviceLocationLabel(
        _service([_plateau, _pikine, _rufisque]),
        l10n,
        origin: (lat: 14.7167, lng: -17.2667),
      );
      expect(label, startsWith('Rufisque · '));
      expect(label, isNot(contains('Dakar Plateau')));
      expect(label, isNot(contains('Pikine')));
    });

    test('the count of other zones is dropped once a distance is shown', () {
      // The distance already answers the question the filter asked. Adding
      // "+2" on top would spend scarce card width restating it.
      final label = serviceLocationLabel(
        _service([_plateau, _rufisque, _pikine]),
        l10n,
        origin: (lat: 14.6693, lng: -17.4381),
      );
      expect(label, 'Dakar Plateau · 0.0 km');
      expect(label, isNot(contains('+')));
    });

    test('an UNLOCATED zone never wins the closest contest', () {
      // This is the trap. (0, 0) is roughly 1800 km from Dakar and closer to
      // it than almost nothing else, but it is not a position at all: taking
      // part in the arithmetic, it would beat a genuine zone whenever the
      // filter sits far enough out, and the card would announce a distance to
      // a place that was never located.
      final label = serviceLocationLabel(
        _service([_unlocated, _plateau]),
        l10n,
        origin: (lat: 14.6693, lng: -17.4381),
      );
      expect(label, 'Dakar Plateau · 0.0 km');
      expect(label, isNot(contains('Saint-Louis')));
    });

    test('all zones unlocated: the label survives, the distance does not', () {
      // The name the provider typed is still true. Only arithmetic on it
      // would be false, so the label-only form is what is shown.
      final label = serviceLocationLabel(
        _service([_unlocated]),
        l10n,
        origin: (lat: 14.6693, lng: -17.4381),
      );
      expect(label, 'Saint-Louis');
      expect(label, isNot(contains('km')));
    });
  });

  group('the rounding reads, and matches the booking detail', () {
    test('one decimal below 10 km, whole kilometers above', () {
      expect(formatDistanceKm(0.0), '0.0');
      expect(formatDistanceKm(2.54), '2.5');
      expect(formatDistanceKm(9.94), '9.9');
      expect(formatDistanceKm(10.0), '10');
      expect(formatDistanceKm(12.4), '12');
      expect(formatDistanceKm(12.6), '13');
      expect(formatDistanceKm(1834.7), '1835');
    });

    test('a real distance across Dakar rounds to whole kilometers', () {
      final km = haversineKm(
        _plateau.latitude,
        _plateau.longitude,
        _rufisque.latitude,
        _rufisque.longitude,
      );
      expect(km, greaterThan(10));
      expect(
        formatDistanceKm(km),
        isNot(contains('.')),
        reason: 'above 10 km a tenth is noise the display would be faking',
      );
    });
  });

  group('zoneIsLocatable', () {
    test('(0, 0) is a marker for unresolved, not a coordinate', () {
      expect(zoneIsLocatable(_unlocated), isFalse);
      expect(zoneIsLocatable(_plateau), isTrue);
      // A zone on the equator or the prime meridian is still a real place:
      // only BOTH being zero is the marker.
      expect(
        zoneIsLocatable(
          const ServiceZone(
            label: 'Equateur',
            latitude: 0,
            longitude: 11.5,
            radiusKm: 5,
          ),
        ),
        isTrue,
      );
      expect(
        zoneIsLocatable(
          const ServiceZone(
            label: 'Greenwich',
            latitude: 51.48,
            longitude: 0,
            radiusKm: 5,
          ),
        ),
        isTrue,
      );
    });
  });
}
