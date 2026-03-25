import '../models/booking.dart';

abstract interface class BookingRepository {
  Stream<Booking?> watchById(String bookingId);
  Stream<List<Booking>> watchForUser(String userId);

  Future<Booking> create(Booking booking);
  Future<void> update(Booking booking);
  Future<void> cancel(String bookingId);
}
