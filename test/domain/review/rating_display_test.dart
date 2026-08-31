import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/review/rating_display.dart';

void main() {
  group('ratingDisplay', () {
    test('no review at all is new', () {
      expect(ratingDisplay(sum: 0, count: 0).isNew, isTrue);
    });

    test('one and two reviews are still new: one bad day is not a verdict', () {
      expect(ratingDisplay(sum: 2, count: 1).isNew, isTrue);
      expect(ratingDisplay(sum: 4, count: 2).isNew, isTrue);
    });

    test('three reviews earn an average', () {
      final d = ratingDisplay(sum: 12, count: 3);
      expect(d.isNew, isFalse);
      expect(d.average, 4.0);
      expect(d.count, 3);
    });

    test('the average is the real quotient, not a rounded one', () {
      expect(ratingDisplay(sum: 10, count: 3).average, closeTo(3.3333, 0.0001));
    });

    test('a fresh display carries no average and no count', () {
      final d = ratingDisplay(sum: 5, count: 1);
      expect(d.average, isNull);
      expect(d.count, 0);
    });

    test('the floor is a parameter, and lowering it changes the verdict', () {
      expect(ratingDisplay(sum: 2, count: 1, minReviews: 1).isNew, isFalse);
      expect(ratingDisplay(sum: 12, count: 3, minReviews: 5).isNew, isTrue);
    });

    test('a negative or zero count never yields an average', () {
      expect(ratingDisplay(sum: 9, count: 0, minReviews: 0).isNew, isTrue);
      expect(ratingDisplay(sum: 9, count: -2, minReviews: 0).isNew, isTrue);
    });

    test('it hashes and prints itself, so it can key a widget or a log', () {
      expect(
        ratingDisplay(sum: 12, count: 3).hashCode,
        ratingDisplay(sum: 12, count: 3).hashCode,
      );
      expect(ratingDisplay(sum: 12, count: 3).toString(), contains('4.0'));
      expect(const RatingDisplay.fresh().toString(), contains('fresh'));
      expect(ratingDisplay(sum: 0, count: 0), const RatingDisplay.fresh());
      // ignore: unrelated_type_equality_checks
      expect(ratingDisplay(sum: 0, count: 0) == 'not a rating', isFalse);
    });

    test('two identical aggregates compare equal', () {
      expect(
        ratingDisplay(sum: 12, count: 3),
        ratingDisplay(sum: 12, count: 3),
      );
      expect(
        ratingDisplay(sum: 12, count: 3),
        isNot(ratingDisplay(sum: 13, count: 3)),
      );
    });
  });
}
