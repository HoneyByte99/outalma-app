// Unit tests for CategoryIdIcon extension.
// Verifies each CategoryId maps to the expected IconData and no two share
// the same icon.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/features/shared/category_icon.dart';

void main() {
  group('CategoryIdIcon extension', () {
    test('menage maps to cleaning_services_outlined', () {
      expect(CategoryId.menage.icon, equals(Icons.cleaning_services_outlined));
    });

    test('plomberie maps to plumbing_outlined', () {
      expect(CategoryId.plomberie.icon, equals(Icons.plumbing_outlined));
    });

    test('jardinage maps to yard_outlined', () {
      expect(CategoryId.jardinage.icon, equals(Icons.yard_outlined));
    });

    test('electricite maps to electrical_services_outlined', () {
      expect(
        CategoryId.electricite.icon,
        equals(Icons.electrical_services_outlined),
      );
    });

    test('peinture maps to format_paint_outlined', () {
      expect(CategoryId.peinture.icon, equals(Icons.format_paint_outlined));
    });

    test('bricolage maps to handyman_outlined', () {
      expect(CategoryId.bricolage.icon, equals(Icons.handyman_outlined));
    });

    test('gardeEnfants maps to child_care_outlined', () {
      expect(CategoryId.gardeEnfants.icon, equals(Icons.child_care_outlined));
    });

    test('no two CategoryId values share the same icon', () {
      final icons = CategoryId.values.map((c) => c.icon).toList();
      final uniqueIcons = icons.toSet();
      expect(
        uniqueIcons.length,
        equals(icons.length),
        reason: 'Every CategoryId must have a unique icon',
      );
    });

    test('all CategoryId values have an icon defined (exhaustive check)', () {
      for (final category in CategoryId.values) {
        // If the switch were non-exhaustive this would throw at runtime.
        expect(category.icon, isA<IconData>());
      }
    });
  });
}
