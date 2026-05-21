import '../models/booking.dart';

abstract interface class BookingRepository {
  Stream<Booking?> watchById(String bookingId);
  Stream<List<Booking>> watchForCustomer(String customerId);
  Stream<List<Booking>> watchForProvider(String providerId);
}
