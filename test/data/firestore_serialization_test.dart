import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/data/firestore/firestore_serialization.dart';

void main() {
  group('dateTimeFromFirestore', () {
    test('converts Timestamp to UTC DateTime', () {
      final ts = Timestamp.fromDate(DateTime.utc(2024, 6, 15, 12, 0, 0));
      final result = dateTimeFromFirestore(ts);
      expect(result.isUtc, isTrue);
      expect(result.year, 2024);
      expect(result.month, 6);
      expect(result.day, 15);
      expect(result.hour, 12);
    });

    test('converts ISO-8601 String to UTC DateTime', () {
      const iso = '2024-03-01T08:30:00.000Z';
      final result = dateTimeFromFirestore(iso);
      expect(result.isUtc, isTrue);
      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 1);
      expect(result.hour, 8);
      expect(result.minute, 30);
    });

    test('converts int epoch millis to UTC DateTime', () {
      // 1_000_000_000_000 ms = 2001-09-08T21:46:40Z
      final result = dateTimeFromFirestore(1000000000000);
      expect(result.isUtc, isTrue);
      expect(result.year, 2001);
    });

    test('returns epoch zero for null', () {
      final result = dateTimeFromFirestore(null);
      expect(result, equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
    });

    test('returns epoch zero for unrecognised type', () {
      final result = dateTimeFromFirestore(Object());
      expect(result, equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
    });
  });

  group('dateTimeToFirestore', () {
    test('returns a Timestamp', () {
      final dt = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final result = dateTimeToFirestore(dt);
      expect(result, isA<Timestamp>());
    });

    test('roundtrips through dateTimeFromFirestore', () {
      final original = DateTime.utc(2024, 12, 31, 23, 59, 59);
      final ts = dateTimeToFirestore(original);
      final recovered = dateTimeFromFirestore(ts);
      expect(recovered.year, original.year);
      expect(recovered.month, original.month);
      expect(recovered.day, original.day);
      expect(recovered.hour, original.hour);
      expect(recovered.minute, original.minute);
      expect(recovered.second, original.second);
    });
  });
}
