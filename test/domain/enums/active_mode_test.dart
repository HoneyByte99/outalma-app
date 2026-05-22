import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/active_mode.dart';

void main() {
  group('ActiveMode', () {
    test('has exactly two values', () {
      expect(ActiveMode.values.length, 2);
    });

    test('fromString parses client', () {
      expect(ActiveMode.fromString('client'), ActiveMode.client);
    });

    test('fromString parses provider', () {
      expect(ActiveMode.fromString('provider'), ActiveMode.provider);
    });

    test('fromString falls back to client for unknown string', () {
      expect(ActiveMode.fromString('unknown'), ActiveMode.client);
    });

    test('fromString falls back to client for empty string', () {
      expect(ActiveMode.fromString(''), ActiveMode.client);
    });

    test('round-trip through name for all values', () {
      for (final mode in ActiveMode.values) {
        expect(ActiveMode.fromString(mode.name), mode);
      }
    });
  });
}
