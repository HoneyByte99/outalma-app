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
}
