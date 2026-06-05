import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/callable_function_client.dart';

/// Calls the server-authoritative `acceptBooking` Cloud Function.
/// Creates the chat document and sets chatId on the booking.
class AcceptBookingUseCase {
  const AcceptBookingUseCase();

  Future<void> call(String bookingId) async {
    await const CallableFunctionClient().call(
      'acceptBooking',
      data: {'bookingId': bookingId},
    );
  }
}

/// Calls the server-authoritative `rejectBooking` Cloud Function.
class RejectBookingUseCase {
  const RejectBookingUseCase();

  Future<void> call(String bookingId) async {
    await const CallableFunctionClient().call(
      'rejectBooking',
      data: {'bookingId': bookingId},
    );
  }
}

/// Calls the server-authoritative `markInProgress` Cloud Function.
/// Provider-only. Booking must be in `accepted` status.
class MarkInProgressUseCase {
  const MarkInProgressUseCase();

  Future<void> call(String bookingId) async {
    await const CallableFunctionClient().call(
      'markInProgress',
      data: {'bookingId': bookingId},
    );
  }
}

/// Calls the server-authoritative `confirmDone` Cloud Function.
/// Client-only. Booking must be in `in_progress` status.
class ConfirmDoneUseCase {
  const ConfirmDoneUseCase();

  Future<void> call(String bookingId) async {
    await const CallableFunctionClient().call(
      'confirmDone',
      data: {'bookingId': bookingId},
    );
  }
}

/// Calls the server-authoritative `cancelBooking` Cloud Function.
/// Only valid when booking status = `requested`.
class CancelBookingUseCase {
  const CancelBookingUseCase();

  Future<void> call(String bookingId) async {
    await const CallableFunctionClient().call(
      'cancelBooking',
      data: {'bookingId': bookingId},
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final acceptBookingUseCaseProvider = Provider<AcceptBookingUseCase>(
  (_) => const AcceptBookingUseCase(),
);

final rejectBookingUseCaseProvider = Provider<RejectBookingUseCase>(
  (_) => const RejectBookingUseCase(),
);

final markInProgressUseCaseProvider = Provider<MarkInProgressUseCase>(
  (_) => const MarkInProgressUseCase(),
);

final confirmDoneUseCaseProvider = Provider<ConfirmDoneUseCase>(
  (_) => const ConfirmDoneUseCase(),
);

final cancelBookingUseCaseProvider = Provider<CancelBookingUseCase>(
  (_) => const CancelBookingUseCase(),
);
