import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/identity/batch_id.dart';

void main() {
  group('isValidBatchId', () {
    test('accepts the server window: 8 to 64 of [A-Za-z0-9_-]', () {
      expect(isValidBatchId('a' * 8), isTrue);
      expect(isValidBatchId('A' * 64), isTrue);
      expect(isValidBatchId('aZ0_-aZ0'), isTrue);
      expect(isValidBatchId('0123456789abcdef0123456789abcdef'), isTrue);
    });

    test('rejects too short and too long', () {
      expect(isValidBatchId('a' * 7), isFalse);
      expect(isValidBatchId('a' * 65), isFalse);
      expect(isValidBatchId(''), isFalse);
    });

    test('rejects characters outside the allowlist', () {
      expect(isValidBatchId('has a space '), isFalse);
      expect(isValidBatchId('slash/inside/it!'), isFalse);
      expect(isValidBatchId('dots.are.not.ok'), isFalse);
    });
  });
}
