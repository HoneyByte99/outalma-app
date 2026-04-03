import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreBookingRepository implements BookingRepository {
  const FirestoreBookingRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Booking?> watchById(String bookingId) {
    return FirestoreCollections.bookings(_db)
        .doc(bookingId)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Stream<List<Booking>> watchForCustomer(String customerId) {
    return FirestoreCollections.bookings(_db)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  @override
  Stream<List<Booking>> watchForProvider(String providerId) {
    return FirestoreCollections.bookings(_db)
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  /// Creates a booking document directly in Firestore.
  ///
  /// For server-authoritative creation prefer the `createBooking` Cloud
  /// Function. This method exists for local development and testing.
  @override
  Future<Booking> create(Booking booking) async {
    final col = FirestoreCollections.bookings(_db);
    if (booking.id.isEmpty) {
      final ref = col.doc();
      // The Booking model's id is immutable via copyWith, but the Firestore
      // converter reads snap.id, so the returned object will have the correct id.
      await ref.set(booking);
      final snap = await ref.get();
      if (!snap.exists || snap.data() == null) {
        throw Exception('Booking creation failed: document not found after set');
      }
      return snap.data()!;
    } else {
      await col.doc(booking.id).set(booking);
      return booking;
    }
  }

  @override
  Future<void> update(Booking booking) async {
    await FirestoreCollections.bookings(_db)
        .doc(booking.id)
        .set(booking, SetOptions(merge: true));
  }

  @override
  Future<void> cancel(String bookingId) async {
    // Critical status transitions are handled by the cancelBooking Cloud
    // Function. This method exists as a convenience shim; in production the
    // application layer should call the Function directly.
    await FirestoreCollections.bookings(_db).doc(bookingId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}
