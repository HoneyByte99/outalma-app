import '../enums/booking_status.dart';

class Booking {
  const Booking({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  final String id;
  final String userId;
  final String serviceId;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  Booking copyWith({
    String? userId,
    String? serviceId,
    DateTime? startAt,
    DateTime? endAt,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return Booking(
      id: id,
      userId: userId ?? this.userId,
      serviceId: serviceId ?? this.serviceId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'userId': userId,
      'serviceId': serviceId,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'notes': notes,
    };
  }

  static Booking fromJson(String id, Map<String, Object?> json) {
    DateTime parseUtc(Object? raw) {
      if (raw is String) return DateTime.parse(raw).toUtc();
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return Booking(
      id: id,
      userId: (json['userId'] as String?) ?? '',
      serviceId: (json['serviceId'] as String?) ?? '',
      startAt: parseUtc(json['startAt']),
      endAt: parseUtc(json['endAt']),
      status: BookingStatus.fromString(
        (json['status'] as String?) ?? BookingStatus.pending.name,
      ),
      createdAt: parseUtc(json['createdAt']),
      updatedAt: parseUtc(json['updatedAt']),
      notes: json['notes'] as String?,
    );
  }
}
