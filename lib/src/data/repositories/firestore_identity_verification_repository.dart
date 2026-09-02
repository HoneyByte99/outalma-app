import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/enums/identity_status.dart';
import '../../domain/models/identity_verification_record.dart';
import '../../domain/repositories/identity_verification_repository.dart';

/// Reads `identity_verifications` for the file's owner (archi 5.6).
///
/// The Firestore rule authorises a read only when
/// `resource.data.providerId == request.auth.uid` (firestore.rules:116), so
/// this query is safe for the owner and refused for anyone else. The internal
/// subcollection carrying the duplicate flag and reviewer identity is never
/// touched here (AC-C20).
class FirestoreIdentityVerificationRepository
    implements IdentityVerificationRepository {
  const FirestoreIdentityVerificationRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<IdentityVerificationRecord?> watchLatest(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collection('identity_verifications')
        .where('providerId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return _fromData(snap.docs.first.data());
        });
  }

  static IdentityVerificationRecord _fromData(Map<String, dynamic> data) {
    return IdentityVerificationRecord(
      status: IdentityStatus.fromString(data['status'] as String?),
      // A missing attempt reads as the first: a file always has at least one.
      attempt: (data['attempt'] as num?)?.toInt() ?? 1,
      priority: data['priority'] as bool? ?? false,
      rejectionReason: data['rejectionReason'] as String?,
      submittedAt: _toDate(data['submittedAt']),
      reviewedAt: _toDate(data['reviewedAt']),
    );
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toUtc();
    return null;
  }
}
