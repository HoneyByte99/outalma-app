import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/avatars/avatar_catalog.dart';

void main() {
  group('AvatarCatalog.parse accepts', () {
    test('a human with every tone, and maps t1..t6 to index 0..5', () {
      for (var i = 0; i < AvatarCatalog.skinTones.length; i++) {
        final ref = AvatarCatalog.parse('human_afro1_t${i + 1}');
        expect(ref, isNotNull, reason: 'tone t${i + 1} should resolve');
        expect(ref!.toneIndex, i);
        expect(ref.skinToneArgb, AvatarCatalog.skinTones[i]);
        expect(ref.assetPath, 'assets/avatars/human_afro1.svg');
      }
    });

    test('a human with NO tone, falling back to the default', () {
      // Written by an older client, or before the suffix existed. Drawing it
      // in the default tone beats refusing to draw.
      final ref = AvatarCatalog.parse('human_afro1');
      expect(ref, isNotNull);
      expect(ref!.toneIndex, AvatarCatalog.defaultToneIndex);
      expect(ref.skinToneArgb, AvatarCatalog.skinTones[1]);
    });

    test('an animal, with no tone at all', () {
      final ref = AvatarCatalog.parse('animal_blob1');
      expect(ref, isNotNull);
      expect(ref!.assetPath, 'assets/avatars/animal_blob1.svg');
      expect(ref.toneIndex, isNull);
      expect(ref.skinToneArgb, isNull, reason: 'an animal has no skin');
    });

    test(
      'an animal carrying a tone, dropping the tone rather than refusing',
      () {
        // The server grammar does not couple "animal" to "no tone" on purpose,
        // so the client must cope with the combination.
        final ref = AvatarCatalog.parse('animal_blob1_t4');
        expect(ref, isNotNull);
        expect(ref!.skinToneArgb, isNull);
      },
    );
  });

  group('AvatarCatalog.parse refuses, and never throws', () {
    // One entry per reason, so a failure names what broke.
    const cases = <String, String?>{
      'null': null,
      'empty': '',
      'blank': '   ',
      'unknown family': 'robot_afro1',
      'unknown character': 'human_notinthecatalogue',
      'tone 0, below the range': 'human_afro1_t0',
      'tone 7, above the range': 'human_afro1_t7',
      'repeated tone suffix': 'human_afro1_t3_t3',
      'uppercase, refused not normalised': 'Human_Afro1_t3',
      'leading space': ' human_afro1_t3',
      'trailing space': 'human_afro1_t3 ',
      'trailing newline': 'human_afro1_t3\n',
      'prefixed': 'x_human_afro1_t3',
      'empty slug': 'human_',
      'path traversal': 'human_../../etc/passwd',
      'encoded traversal': 'human_..%2f..%2fetc',
      'slash in slug': 'animal_a/b',
      'dot in slug': 'human_afro.1',
      'underscore run': 'human__afro1',
    };

    cases.forEach((reason, value) {
      test(reason, () {
        expect(AvatarCatalog.parse(value), isNull);
      });
    });

    test('an absurdly long value', () {
      expect(AvatarCatalog.parse('human_${'a' * 1000}'), isNull);
    });
  });

  group('the grammar', () {
    test('accepts exactly the ids the catalogue can produce, and no more', () {
      final pattern = RegExp(AvatarCatalog.idPattern);

      // Every id the app can write must be grammatical.
      for (final human in AvatarCatalog.humanIds) {
        for (var i = 0; i < AvatarCatalog.skinTones.length; i++) {
          final id = AvatarCatalog.composeId(human, i);
          expect(pattern.hasMatch(id), isTrue, reason: '$id should match');
          expect(AvatarCatalog.parse(id), isNotNull);
        }
      }
      for (final animal in AvatarCatalog.animalIds) {
        final id = AvatarCatalog.composeId(animal, 3);
        expect(id, animal, reason: 'an animal id carries no tone');
        expect(pattern.hasMatch(id), isTrue);
        expect(AvatarCatalog.parse(id), isNotNull);
      }
    });

    test('bounds the length, so no separate size cap is needed', () {
      final pattern = RegExp(AvatarCatalog.idPattern);
      // The longest grammatical id is the longer family plus a full slug plus a
      // tone: 'animal_' + 20 + '_t6'. 30 characters, and nothing longer parses.
      const longest = 'animal_aaaaaaaaaaaaaaaaaaaa_t6';
      expect(longest.length, 30);
      expect(pattern.hasMatch(longest), isTrue);
      expect(
        pattern.hasMatch('animal_aaaaaaaaaaaaaaaaaaaaa_t6'),
        isFalse,
        reason: 'a 21-character slug must not parse',
      );
    });
  });

  group('the catalogue itself', () {
    test('holds 28 humans and 12 animals, with no duplicate', () {
      expect(AvatarCatalog.humanIds, hasLength(AvatarCatalog.humanCount));
      expect(AvatarCatalog.animalIds, hasLength(AvatarCatalog.animalCount));
      expect(AvatarCatalog.allIds.toSet(), hasLength(40));
    });

    test('has six tones, six check colours and a default inside range', () {
      expect(AvatarCatalog.skinTones, hasLength(6));
      expect(AvatarCatalog.toneCheckColors, hasLength(6));
      expect(
        AvatarCatalog.defaultToneIndex,
        inInclusiveRange(0, AvatarCatalog.skinTones.length - 1),
      );
    });

    test('lists the three elders, and they are humans', () {
      expect(AvatarCatalog.elderIds, hasLength(3));
      for (final id in AvatarCatalog.elderIds) {
        expect(AvatarCatalog.humanIds, contains(id));
      }
    });
  });
}
