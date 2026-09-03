// Tests for classifyBookingSubmitError (CADRAGE booking-ux point 3): the
// client classifies a createBooking refusal from its stable `details.code`,
// never from the English prose the zone gate ships today.

import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/domain/booking/booking_submit_error.dart';

void main() {
  group('classifyBookingSubmitError', () {
    test('recognises the zone-coverage code', () {
      expect(
        classifyBookingSubmitError(detailsCode: 'BOOKING_OUTSIDE_ZONES'),
        BookingSubmitErrorKind.outsideZones,
      );
    });

    test('falls back to unknown when details.code is absent', () {
      expect(
        classifyBookingSubmitError(detailsCode: null),
        BookingSubmitErrorKind.unknown,
      );
    });

    test('falls back to unknown for an unrecognised code', () {
      expect(
        classifyBookingSubmitError(detailsCode: 'SOMETHING_ELSE'),
        BookingSubmitErrorKind.unknown,
      );
    });
  });
}
