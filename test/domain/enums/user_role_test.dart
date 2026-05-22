import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/user_role.dart';

void main() {
  group('UserRole', () {
    group('values', () {
      test('contains exactly customer, provider, admin', () {
        expect(UserRole.values, hasLength(3));
        expect(UserRole.values, contains(UserRole.customer));
        expect(UserRole.values, contains(UserRole.provider));
        expect(UserRole.values, contains(UserRole.admin));
      });

      test('all values are non-null', () {
        for (final role in UserRole.values) {
          expect(role, isNotNull);
        }
      });
    });

    group('fromString', () {
      test('parses "customer"', () {
        expect(UserRole.fromString('customer'), UserRole.customer);
      });

      test('parses "provider"', () {
        expect(UserRole.fromString('provider'), UserRole.provider);
      });

      test('parses "admin"', () {
        expect(UserRole.fromString('admin'), UserRole.admin);
      });

      test('unknown value falls back to customer', () {
        expect(UserRole.fromString('unknown'), UserRole.customer);
        expect(UserRole.fromString(''), UserRole.customer);
        expect(UserRole.fromString('ADMIN'), UserRole.customer);
      });

      test('round-trips through name for all values', () {
        for (final role in UserRole.values) {
          expect(UserRole.fromString(role.name), role);
        }
      });
    });
  });
}
