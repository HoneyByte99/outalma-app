import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/message_type.dart';

void main() {
  group('MessageType', () {
    test('has four values', () {
      expect(MessageType.values.length, 4);
    });

    for (final entry in const {
      'text': MessageType.text,
      'image': MessageType.image,
      'voice': MessageType.voice,
      'system': MessageType.system,
    }.entries) {
      test('fromString parses ${entry.key}', () {
        expect(MessageType.fromString(entry.key), entry.value);
      });
    }

    test('fromString falls back to text for unknown string', () {
      expect(MessageType.fromString('video'), MessageType.text);
    });

    test('fromString falls back to text for empty string', () {
      expect(MessageType.fromString(''), MessageType.text);
    });

    test('round-trip through name for all values', () {
      for (final type in MessageType.values) {
        expect(MessageType.fromString(type.name), type);
      }
    });
  });
}
