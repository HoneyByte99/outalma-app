import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Calls the server-authoritative `acceptBooking` Cloud Function.
/// Creates the chat document and sets chatId on the booking.
class AcceptBookingUseCase {
  const AcceptBookingUseCase(this._functions);
  final FirebaseFunctions _functions;

  Future<void> call(String bookingId) async {
    final callable = _functions.httpsCallable('acceptBooking');
    await callable.call<void>({'bookingId': bookingId});
  }
}

/// Calls the server-authoritative `rejectBooking` Cloud Function.
class RejectBookingUseCase {
  const RejectBookingUseCase(this._functions);
  final FirebaseFunctions _functions;

  Future<void> call(String bookingId) async {
    final callable = _functions.httpsCallable('rejectBooking');
    await callable.call<void>({'bookingId': bookingId});
  }
}

/// Calls the server-authoritative `markInProgress` Cloud Function.
/// Provider-only. Booking must be in `accepted` status.
class MarkInProgressUseCase {
  const MarkInProgressUseCase(this._functions);
  final FirebaseFunctions _functions;

  Future<void> call(String bookingId) async {
    final callable = _functions.httpsCallable('markInProgress');
    await callable.call<void>({'bookingId': bookingId});
  }
}

/// Calls the server-authoritative `confirmDone` Cloud Function.
/// Client-only. Booking must be in `in_progress` status.
class ConfirmDoneUseCase {
  const ConfirmDoneUseCase(this._functions);
  final FirebaseFunctions _functions;

  Future<void> call(String bookingId) async {
    final callable = _functions.httpsCallable('confirmDone');
    await callable.call<void>({'bookingId': bookingId});
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final acceptBookingUseCaseProvider = Provider<AcceptBookingUseCase>((ref) {
  return AcceptBookingUseCase(FirebaseFunctions.instance);
});

final rejectBookingUseCaseProvider = Provider<RejectBookingUseCase>((ref) {
  return RejectBookingUseCase(FirebaseFunctions.instance);
});

final markInProgressUseCaseProvider = Provider<MarkInProgressUseCase>((ref) {
  return MarkInProgressUseCase(FirebaseFunctions.instance);
});

final confirmDoneUseCaseProvider = Provider<ConfirmDoneUseCase>((ref) {
  return ConfirmDoneUseCase(FirebaseFunctions.instance);
});
