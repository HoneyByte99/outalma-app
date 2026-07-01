import 'package:flutter/foundation.dart';

enum BookingStatus {
  requested,
  accepted,
  inProgress,
  done,
  rejected,
  cancelled,

  /// Sentinel for an unrecognised status string (TS↔Dart drift, corrupt data).
  /// Treated as a terminal, read-only state so the UI never offers actions on
  /// a booking it cannot reason about - instead of the previous silent fallback
  /// to `requested`, which could re-offer accept/cancel on a closed booking.
  unknown;

  /// Canonical Firestore string values (snake_case).
  String get value {
    switch (this) {
      case BookingStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }

  static BookingStatus fromString(String value) {
    switch (value) {
      case 'requested':
        return BookingStatus.requested;
      case 'accepted':
        return BookingStatus.accepted;
      case 'in_progress':
        return BookingStatus.inProgress;
      case 'done':
        return BookingStatus.done;
      case 'rejected':
        return BookingStatus.rejected;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        if (kDebugMode) {
          debugPrint('BookingStatus.fromString: unknown value "$value"');
        }
        return BookingStatus.unknown;
    }
  }

  /// Returns `true` if transitioning from `this` to [to] is valid per the
  /// Outalma MVP state machine:
  ///
  ///   requested   → accepted, rejected, cancelled
  ///   accepted    → in_progress, cancelled
  ///   in_progress → done, cancelled
  ///   done / rejected / cancelled → (none)
  ///
  /// A booking may be cancelled (by either participant, with a reason) while it
  /// is still active - requested, accepted or in_progress.
  ///
  /// Note: server-side Cloud Functions are the authoritative enforcers.
  /// This method is a client-side guard to prevent offering invalid actions
  /// in the UI.
  bool canTransitionTo(BookingStatus to) {
    switch (this) {
      case BookingStatus.requested:
        return to == BookingStatus.accepted ||
            to == BookingStatus.rejected ||
            to == BookingStatus.cancelled;
      case BookingStatus.accepted:
        return to == BookingStatus.inProgress || to == BookingStatus.cancelled;
      case BookingStatus.inProgress:
        return to == BookingStatus.done || to == BookingStatus.cancelled;
      case BookingStatus.done:
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
      case BookingStatus.unknown:
        return false;
    }
  }
}
