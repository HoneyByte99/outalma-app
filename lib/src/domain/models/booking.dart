import '../enums/booking_status.dart';

class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.status,
    required this.requestMessage,
    required this.createdAt,
    this.scheduledAt,
    this.schedule,
    this.addressSnapshot,
    this.chatId,
    this.acceptedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.startedAt,
    this.doneAt,
    this.audioMessageUrl,
  });

  final String id;
  final String customerId;
  final String providerId;
  final String serviceId;
  final BookingStatus status;
  final String requestMessage;
  final DateTime? scheduledAt;
  final Map<String, Object?>? schedule;
  final Map<String, Object?>? addressSnapshot;
  final String? chatId;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;
  final DateTime? startedAt;
  final DateTime? doneAt;
  final String? audioMessageUrl;

  Booking copyWith({
    String? customerId,
    String? providerId,
    String? serviceId,
    BookingStatus? status,
    String? requestMessage,
    DateTime? scheduledAt,
    Map<String, Object?>? schedule,
    Map<String, Object?>? addressSnapshot,
    String? chatId,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    DateTime? cancelledAt,
    DateTime? startedAt,
    DateTime? doneAt,
    String? audioMessageUrl,
  }) {
    return Booking(
      id: id,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      status: status ?? this.status,
      requestMessage: requestMessage ?? this.requestMessage,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      schedule: schedule ?? this.schedule,
      addressSnapshot: addressSnapshot ?? this.addressSnapshot,
      chatId: chatId ?? this.chatId,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      startedAt: startedAt ?? this.startedAt,
      doneAt: doneAt ?? this.doneAt,
      audioMessageUrl: audioMessageUrl ?? this.audioMessageUrl,
    );
  }
}
