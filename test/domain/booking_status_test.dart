import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';

void main() {
  group('BookingStatus.fromString', () {
    test('parses requested', () {
      expect(BookingStatus.fromString('requested'), BookingStatus.requested);
    });

    test('parses accepted', () {
      expect(BookingStatus.fromString('accepted'), BookingStatus.accepted);
    });

    test('parses in_progress', () {
      expect(BookingStatus.fromString('in_progress'), BookingStatus.inProgress);
    });

    test('parses done', () {
      expect(BookingStatus.fromString('done'), BookingStatus.done);
    });

    test('parses rejected', () {
      expect(BookingStatus.fromString('rejected'), BookingStatus.rejected);
    });

    test('parses cancelled', () {
      expect(BookingStatus.fromString('cancelled'), BookingStatus.cancelled);
    });

    test('unknown value returns requested fallback without throwing', () {
      expect(
        () => BookingStatus.fromString('unknown_value'),
        returnsNormally,
      );
      expect(
        BookingStatus.fromString('unknown_value'),
        BookingStatus.requested,
      );
    });
  });

  group('BookingStatus.value', () {
    test('inProgress serialises to in_progress', () {
      expect(BookingStatus.inProgress.value, 'in_progress');
    });

    test('all other values match their name', () {
      for (final s in BookingStatus.values) {
        if (s == BookingStatus.inProgress) continue;
        expect(s.value, s.name);
      }
    });

    test('value roundtrips through fromString for all canonical statuses', () {
      for (final s in BookingStatus.values) {
        expect(BookingStatus.fromString(s.value), s);
      }
    });
  });
}
