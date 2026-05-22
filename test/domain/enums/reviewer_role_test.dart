import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';

void main() {
  group('ReviewerRole', () {
    test('has exactly two values', () {
      expect(ReviewerRole.values.length, 2);
    });

    test('fromString parses client', () {
      expect(ReviewerRole.fromString('client'), ReviewerRole.client);
    });

    test('fromString parses provider', () {
      expect(ReviewerRole.fromString('provider'), ReviewerRole.provider);
    });

    test('fromString falls back to client for unknown string', () {
      expect(ReviewerRole.fromString('admin'), ReviewerRole.client);
    });

    test('fromString falls back to client for empty string', () {
      expect(ReviewerRole.fromString(''), ReviewerRole.client);
    });

    test('round-trip through name for all values', () {
      for (final role in ReviewerRole.values) {
        expect(ReviewerRole.fromString(role.name), role);
      }
    });

    test('client and provider are distinct', () {
      expect(ReviewerRole.client, isNot(ReviewerRole.provider));
    });
  });
}
