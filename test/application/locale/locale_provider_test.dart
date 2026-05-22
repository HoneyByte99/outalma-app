// Tests for LocaleNotifier.
//
// Covered:
//   - Default state is null (follow device locale)
//   - setLocale(fr) updates state to Locale('fr')
//   - setLocale(en) updates state to Locale('en')
//   - setLocale(null) resets state to null
//   - Switch fr → en updates state correctly
//   - Persisted locale is restored after container rebuild
//   - setLocale(null) removes persisted value — next container starts null
//   - setLocale updates Intl.defaultLocale

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:outalma_app/src/application/locale/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer() => ProviderContainer();

/// Triggers build and waits for the async _loadFromPrefs() to complete.
///
/// The notifier's build() fires _loadFromPrefs() as a fire-and-forget async
/// call. Reading the provider kicks off build; a short delay lets
/// SharedPreferences.getInstance() and the subsequent state update settle.
Future<void> _settle(ProviderContainer container) async {
  container.read(localeProvider); // trigger build if not yet started
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Intl.defaultLocale = null;
  });

  group('LocaleNotifier — default state', () {
    test('initial state is null (follow device locale)', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      expect(container.read(localeProvider), isNull);
    });

    test('state remains null after async prefs load with no stored value',
        () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _settle(container);

      expect(container.read(localeProvider), isNull);
    });
  });

  group('LocaleNotifier — setLocale', () {
    test('setLocale(fr) updates state to Locale("fr")', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));

      expect(container.read(localeProvider), const Locale('fr'));
    });

    test('setLocale(en) updates state to Locale("en")', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('en'));

      expect(container.read(localeProvider), const Locale('en'));
    });

    test('switch fr → en updates state correctly', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));
      await container.read(localeProvider.notifier).setLocale(const Locale('en'));

      expect(container.read(localeProvider), const Locale('en'));
    });

    test('setLocale(null) resets state to null', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));
      await container.read(localeProvider.notifier).setLocale(null);

      expect(container.read(localeProvider), isNull);
    });
  });

  group('LocaleNotifier — Intl side-effect', () {
    test('setLocale updates Intl.defaultLocale', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));

      expect(Intl.defaultLocale, 'fr_FR');
    });

    test('setLocale(null) clears Intl.defaultLocale', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));
      await container.read(localeProvider.notifier).setLocale(null);

      expect(Intl.defaultLocale, isNull);
    });
  });

  group('LocaleNotifier — persistence', () {
    test('persisted fr locale is restored on container rebuild', () async {
      final c1 = _makeContainer();
      await c1.read(localeProvider.notifier).setLocale(const Locale('fr'));
      c1.dispose();

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      await _settle(c2);

      expect(c2.read(localeProvider), const Locale('fr'));
    });

    test('setLocale(null) removes persisted value — next container starts null',
        () async {
      final c1 = _makeContainer();
      await c1.read(localeProvider.notifier).setLocale(const Locale('fr'));
      await c1.read(localeProvider.notifier).setLocale(null);
      c1.dispose();

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      await _settle(c2);

      expect(c2.read(localeProvider), isNull);
    });
  });
}
