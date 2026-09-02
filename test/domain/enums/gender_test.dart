// The parser of the declared gender. Its whole job is to refuse to guess.
//
// Every account in production predates the field, and a legacy FlutterFlow
// export used the SAME key name with another vocabulary, so the input this
// parser actually meets is mostly "not one of the two values". What it returns
// then decides whether a public card shows a wrong pictogram beside a real
// person's name.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/gender.dart';

void main() {
  group('Gender.tryParse', () {
    test('parses the two canonical values', () {
      expect(Gender.tryParse('male'), Gender.male);
      expect(Gender.tryParse('female'), Gender.female);
    });

    test('every value roundtrips through its stored name', () {
      for (final g in Gender.values) {
        expect(Gender.tryParse(g.name), g);
      }
    });

    test('the enum has exactly two values, by product decision', () {
      // Not decoration. A third value added without touching the interface
      // would fall through GenderIcon's exhaustive switch at compile time, and
      // this test states that the number itself was chosen.
      expect(Gender.values, hasLength(2));
    });

    test('an absent value is null, NOT a default', () {
      expect(Gender.tryParse(null), isNull);
    });

    test('an unknown string is null rather than the nearest match', () {
      for (final input in ['Male', 'FEMALE', 'homme', 'femme', 'M', 'F', '']) {
        expect(
          Gender.tryParse(input),
          isNull,
          reason: '"$input" must not be coerced into a declaration',
        );
      }
    });

    test('a non-string value is null and does not throw', () {
      // What a legacy export or a patched client can actually put in the field.
      for (final Object input in [
        1,
        true,
        <String>['male'],
        <String, String>{},
      ]) {
        expect(Gender.tryParse(input), isNull);
      }
    });
  });
}
