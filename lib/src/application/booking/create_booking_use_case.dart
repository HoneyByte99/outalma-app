import 'package:cloud_functions/cloud_functions.dart';

/// Calls the server-authoritative `createBooking` Cloud Function.
///
/// All booking creation must go through the server to enforce
/// security rules and status integrity.
///
/// Returns the bookingId string on success.
/// Throws [FirebaseFunctionsException] on known server errors.
/// Throws [Exception] on unexpected errors.
class CreateBookingUseCase {
  const CreateBookingUseCase(this._functions);

  final FirebaseFunctions _functions;

  Future<String> call({
    required String providerId,
    required String serviceId,
    required String requestMessage,
    DateTime? scheduledAt,
    String? schedule,
    String? address,
    double? addressLat,
    double? addressLng,
    String? audioMessageUrl,
  }) async {
    final callable = _functions.httpsCallable('createBooking');

    final payload = <String, Object?>{
      'providerId': providerId,
      'serviceId': serviceId,
      'requestMessage': requestMessage,
      if (scheduledAt != null)
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (schedule != null && schedule.isNotEmpty)
        'schedule': {'description': schedule},
      if (address != null && address.isNotEmpty)
        'addressSnapshot': <String, Object?>{
          'address': address,
          if (addressLat != null && addressLng != null) ...{
            'lat': addressLat,
            'lng': addressLng,
          },
        },
      if (audioMessageUrl != null && audioMessageUrl.isNotEmpty)
        'audioMessageUrl': audioMessageUrl,
    };

    final result = await callable.call<Map<String, dynamic>>(payload);
    final data = result.data;

    final bookingId = data['bookingId'] as String?;
    if (bookingId == null || bookingId.isEmpty) {
      throw Exception('createBooking returned no bookingId');
    }

    return bookingId;
  }
}
