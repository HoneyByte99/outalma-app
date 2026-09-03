/// Classification of a `createBooking` refusal into an actionable kind, pure
/// and testable, on the same footing as `classifyIdentitySubmitError`
/// (`identity_submit_error.dart`): the client branches on a stable
/// `details.code`, never on `e.message` prose.
///
/// Only one refusal needs this today (CADRAGE booking-ux point 3): the
/// zone-coverage gate, whose server message is English while every other
/// `createBooking` refusal is already French. Everything else stays on the
/// existing `e.message` fallback, so this classifier only recognises the one
/// code the server emits.
library;

enum BookingSubmitErrorKind {
  /// The address failed the server's zone-coverage gate. Identified by
  /// `details.code == 'BOOKING_OUTSIDE_ZONES'`.
  outsideZones,

  /// Unclassified: the caller falls back to the raw server message.
  unknown,
}

/// Classifies a `createBooking` refusal from its stable [detailsCode].
BookingSubmitErrorKind classifyBookingSubmitError({String? detailsCode}) {
  return detailsCode == 'BOOKING_OUTSIDE_ZONES'
      ? BookingSubmitErrorKind.outsideZones
      : BookingSubmitErrorKind.unknown;
}
