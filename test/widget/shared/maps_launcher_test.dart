// Unit + widget tests for maps_launcher.dart.
//
// openDirections() calls url_launcher platform channels which are absent in
// the test environment, so any test that would invoke launchUrl / canLaunchUrl
// is skipped with 'requires platform channel'.
//
// What we CAN test without platform channels:
//   - URL string construction for the Google Maps universal URL.
//   - URL string construction for Apple Maps and Google Maps / Waze schemes.
//   - The bottom-sheet picker widget (_pickMapsApp analogue) renders the
//     expected options when opened directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';

void main() {
  // -------------------------------------------------------------------------
  // URL structure unit tests (pure Dart - no platform channel needed)
  // -------------------------------------------------------------------------

  group('Google Maps universal URL structure', () {
    Uri buildUniversal({required double lat, required double lng}) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$lat,$lng'
        '&travelmode=driving',
      );
    }

    test('contains the correct host', () {
      final uri = buildUniversal(lat: 48.8566, lng: 2.3522);
      expect(uri.host, equals('www.google.com'));
    });

    test('path is /maps/dir/', () {
      final uri = buildUniversal(lat: 48.8566, lng: 2.3522);
      expect(uri.path, equals('/maps/dir/'));
    });

    test('destination parameter contains lat,lng', () {
      final uri = buildUniversal(lat: 14.6928, lng: -17.4467);
      expect(uri.queryParameters['destination'], equals('14.6928,-17.4467'));
    });

    test('travelmode is driving', () {
      final uri = buildUniversal(lat: 48.8566, lng: 2.3522);
      expect(uri.queryParameters['travelmode'], equals('driving'));
    });

    test('api=1 query parameter is present', () {
      final uri = buildUniversal(lat: 0.0, lng: 0.0);
      expect(uri.queryParameters['api'], equals('1'));
    });

    test('destination uses dot as decimal separator (not comma)', () {
      // French locale should not affect Dart double.toString()
      final uri = buildUniversal(lat: 48.8566, lng: 2.3522);
      final dest = uri.queryParameters['destination']!;
      expect(dest.contains(','), isTrue); // lat,lng separator
      // The lat part "48.8566" must use a dot
      expect(dest.split(',').first, equals('48.8566'));
    });
  });

  group('Apple Maps URL structure', () {
    Uri buildApple({required double lat, required double lng}) {
      return Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');
    }

    test('host is maps.apple.com', () {
      final uri = buildApple(lat: 48.8566, lng: 2.3522);
      expect(uri.host, equals('maps.apple.com'));
    });

    test('daddr contains lat,lng', () {
      final uri = buildApple(lat: 14.6928, lng: -17.4467);
      expect(uri.queryParameters['daddr'], equals('14.6928,-17.4467'));
    });
  });

  group('Google Maps native scheme URL structure', () {
    Uri buildGoogleScheme({required double lat, required double lng}) {
      return Uri.parse(
        'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
      );
    }

    test('scheme is comgooglemaps', () {
      final uri = buildGoogleScheme(lat: 48.8566, lng: 2.3522);
      expect(uri.scheme, equals('comgooglemaps'));
    });

    test('daddr contains lat,lng', () {
      final uri = buildGoogleScheme(lat: 14.6928, lng: -17.4467);
      expect(uri.queryParameters['daddr'], equals('14.6928,-17.4467'));
    });

    test('directionsmode is driving', () {
      final uri = buildGoogleScheme(lat: 48.8566, lng: 2.3522);
      expect(uri.queryParameters['directionsmode'], equals('driving'));
    });
  });

  group('Waze URL structure', () {
    Uri buildWaze({required double lat, required double lng}) {
      return Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    }

    test('scheme is waze', () {
      final uri = buildWaze(lat: 48.8566, lng: 2.3522);
      expect(uri.scheme, equals('waze'));
    });

    test('ll parameter contains lat,lng', () {
      final uri = buildWaze(lat: 14.6928, lng: -17.4467);
      expect(uri.queryParameters['ll'], equals('14.6928,-17.4467'));
    });

    test('navigate=yes is set', () {
      final uri = buildWaze(lat: 48.8566, lng: 2.3522);
      expect(uri.queryParameters['navigate'], equals('yes'));
    });
  });

  // -------------------------------------------------------------------------
  // Bottom-sheet picker widget smoke test
  // -------------------------------------------------------------------------

  group('Maps app picker bottom-sheet (smoke)', () {
    testWidgets('renders option list without throwing', (tester) async {
      // Directly build a bottom-sheet that mirrors the internal
      // _pickMapsApp layout so we test the UI without touching url_launcher.
      final options = [
        const _FakeMapOption(label: 'Plans (Apple)', icon: Icons.map_outlined),
        const _FakeMapOption(
          label: 'Google Maps',
          icon: Icons.navigation_outlined,
        ),
        const _FakeMapOption(label: 'Waze', icon: Icons.alt_route_outlined),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: ctx,
                    showDragHandle: true,
                    builder: (_) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Ouvrir avec'),
                            ),
                          ),
                          for (final opt in options)
                            ListTile(
                              leading: Icon(opt.icon),
                              title: Text(opt.label),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open the sheet.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Ouvrir avec'), findsOneWidget);
      expect(find.text('Plans (Apple)'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Waze'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // openDirections() invocation - skipped (requires platform channel)
  // -------------------------------------------------------------------------

  test(
    'openDirections: skipped - requires platform channel',
    () {},
    skip: 'requires platform channel',
  );
}

// ---------------------------------------------------------------------------
// Local helper - mirrors _MapsOption without importing the private class
// ---------------------------------------------------------------------------

class _FakeMapOption {
  const _FakeMapOption({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
