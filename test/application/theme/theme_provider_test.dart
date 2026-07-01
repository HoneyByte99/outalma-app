// Tests for ThemeModeNotifier.
//
// Covered:
//   - Default state is ThemeMode.system on fresh prefs
//   - setThemeMode(light) updates state to ThemeMode.light
//   - setThemeMode(dark) updates state to ThemeMode.dark
//   - setThemeMode(system) updates state to ThemeMode.system
//   - Persisted value is restored after container rebuild
//   - Toggle light → dark persists correctly
//   - Toggle dark → light persists correctly
//   - Unknown persisted string falls back to ThemeMode.system

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/theme/theme_provider.dart';
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
  container.read(themeModeProvider); // trigger build if not yet started
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier - default state', () {
    test('initial state is ThemeMode.system when no prefs stored', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // Synchronous initial state before the async load resolves.
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test(
      'state remains ThemeMode.system after async prefs load with no value',
      () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await _settle(container);

        expect(container.read(themeModeProvider), ThemeMode.system);
      },
    );
  });

  group('ThemeModeNotifier - setThemeMode', () {
    test('setThemeMode(light) updates state to ThemeMode.light', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setThemeMode(dark) updates state to ThemeMode.dark', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('setThemeMode(system) updates state to ThemeMode.system', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.system);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('ThemeModeNotifier - persistence', () {
    test('persisted light value is restored on container rebuild', () async {
      final c1 = _makeContainer();
      await c1.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      c1.dispose();

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      await _settle(c2);

      expect(c2.read(themeModeProvider), ThemeMode.light);
    });

    test('toggle light → dark persists correctly', () async {
      final c1 = _makeContainer();
      await c1.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      await c1.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      c1.dispose();

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      await _settle(c2);

      expect(c2.read(themeModeProvider), ThemeMode.dark);
    });

    test('toggle dark → light persists correctly', () async {
      final c1 = _makeContainer();
      await c1.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      await c1.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      c1.dispose();

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      await _settle(c2);

      expect(c2.read(themeModeProvider), ThemeMode.light);
    });

    test('unknown persisted string falls back to ThemeMode.system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'unknown_value'});

      final container = _makeContainer();
      addTearDown(container.dispose);
      await _settle(container);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });
}
