// Tests for PhoneField : validates static validate() logic and widget rendering.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/features/shared/phone_field.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('PhoneField.validate()', () {
    test('null value returns null (optional field)', () {
      expect(PhoneField.validate(null), isNull);
    });

    test('empty string returns null (optional field)', () {
      expect(PhoneField.validate(''), isNull);
    });

    test('valid French number returns null', () {
      expect(PhoneField.validate('+33612345678'), isNull);
    });

    test('too short number returns non-null error string', () {
      final result = PhoneField.validate('+33123');
      expect(result, isNotNull);
      expect(result, isA<String>());
    });

    test('too long number (>15 digits) returns non-null error string', () {
      final result = PhoneField.validate('+331234567890123456');
      expect(result, isNotNull);
      expect(result, isA<String>());
    });

    test('valid Senegalese number returns null', () {
      expect(PhoneField.validate('+221701234567'), isNull);
    });
  });

  group('PhoneField widget', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(PhoneField(onChanged: (_) {})));
      await tester.pump();
      // Basic check: the field renders something
      expect(find.byType(PhoneField), findsOneWidget);
    });

    testWidgets('renders with initialValue without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(PhoneField(initialValue: '+33612345678', onChanged: (_) {})),
      );
      await tester.pump();
      expect(find.byType(PhoneField), findsOneWidget);
    });

    testWidgets('default country chip shows French flag and dial code', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(PhoneField(onChanged: (_) {})));
      await tester.pump();
      // French flag emoji should be visible
      expect(find.text('🇫🇷'), findsOneWidget);
      expect(find.text('+33'), findsOneWidget);
    });

    testWidgets('initialValue +221 shows Senegalese flag and dial code', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PhoneField(initialValue: '+221701234567', onChanged: (_) {})),
      );
      await tester.pump();
      expect(find.text('🇸🇳'), findsOneWidget);
      expect(find.text('+221'), findsOneWidget);
    });
  });

  // The country list carries accents ("Senegal" with an acute e), and someone
  // signing up on a phone in Dakar types without them. TWO mirrored cases, or
  // folding a single side passes and the other mutation survives.
  group('PhoneField country picker: accent-insensitive', () {
    Finder inList(String label) =>
        find.descendant(of: find.byType(ListView), matching: find.text(label));

    Future<void> openPicker(WidgetTester tester) async {
      await tester.pumpWidget(_wrap(PhoneField(onChanged: (_) {})));
      await tester.pump();
      // The dial-code chip opens the sheet.
      await tester.tap(find.text('+33'));
      await tester.pumpAndSettle();
    }

    testWidgets('an UNACCENTED query finds an ACCENTED country', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.enterText(find.byType(TextField).last, 'senegal');
      await tester.pumpAndSettle();

      expect(
        inList('S\u00e9n\u00e9gal'),
        findsOneWidget,
        reason: 'the fold must apply to the country NAME side',
      );
      expect(inList('France'), findsNothing);
    });

    testWidgets('an ACCENTED query finds the same country', (tester) async {
      await openPicker(tester);
      await tester.enterText(find.byType(TextField).last, 'S\u00e9n\u00e9gal');
      await tester.pumpAndSettle();

      expect(
        inList('S\u00e9n\u00e9gal'),
        findsOneWidget,
        reason: 'the fold must apply to the QUERY side too',
      );
    });

    testWidgets('a dial code still filters, and a miss filters everything', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.enterText(find.byType(TextField).last, '+221');
      await tester.pumpAndSettle();
      expect(inList('S\u00e9n\u00e9gal'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'zzzz');
      await tester.pumpAndSettle();
      expect(inList('S\u00e9n\u00e9gal'), findsNothing);
      expect(inList('France'), findsNothing);
    });
  });
}
