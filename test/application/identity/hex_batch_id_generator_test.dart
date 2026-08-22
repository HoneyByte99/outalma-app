import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/application/identity/hex_batch_id_generator.dart';
import 'package:outalma_app/src/domain/identity/batch_id.dart';

void main() {
  group('HexBatchIdGenerator', () {
    test('produces a 32-char id the server would accept', () {
      final id = HexBatchIdGenerator().generate();
      expect(id.length, 32);
      expect(isValidBatchId(id), isTrue);
    });

    test('produces a fresh id each call (new batch per attempt, AC-C12)', () {
      final gen = HexBatchIdGenerator();
      final ids = List.generate(50, (_) => gen.generate());
      expect(ids.toSet().length, 50);
    });
  });
}
