import '../../../l10n/app_localizations.dart';
import '../../domain/enums/booking_status.dart';

/// Localized labels for [BookingStatus], shared so the inbox chip and the
/// calendar tile never drift (M2): a provider must never see a raw enum token
/// like "in_progress" on screen.
extension BookingStatusLabel on BookingStatus {
  String labelOf(AppLocalizations l10n) => switch (this) {
    BookingStatus.requested => l10n.statusPending,
    BookingStatus.accepted => l10n.statusAccepted,
    BookingStatus.inProgress => l10n.statusInProgress,
    BookingStatus.done => l10n.statusDone,
    BookingStatus.rejected => l10n.statusRejected,
    BookingStatus.cancelled => l10n.statusCancelled,
    BookingStatus.unknown => '-',
  };

  /// Whether the booking is still live (shown on the calendar as a real
  /// appointment). Terminal states (done/rejected/cancelled/unknown) are hidden
  /// from the day markers so a refused request never looks like a booking.
  bool get isActive =>
      this == BookingStatus.requested ||
      this == BookingStatus.accepted ||
      this == BookingStatus.inProgress;
}
