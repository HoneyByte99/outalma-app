import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal, defensive helpers for Firestore <-> Domain conversions.
///
/// Domain models generally use `DateTime` (UTC). Firestore may store timestamps
/// as [Timestamp], ISO-8601 [String], or (rarely) epoch millis [int].
DateTime dateTimeFromFirestore(Object? raw) {
  if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  if (raw is Timestamp) return raw.toDate().toUtc();
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) return DateTime.parse(raw).toUtc();
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

Object dateTimeToFirestore(DateTime value) => Timestamp.fromDate(value.toUtc());
