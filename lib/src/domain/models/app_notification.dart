class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.bookingId,
    this.chatId,
  });

  final String id;

  /// One of: 'booking_accepted', 'booking_rejected', 'booking_in_progress',
  /// 'booking_done', 'new_message'.
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? bookingId;
  final String? chatId;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    read: read ?? this.read,
    createdAt: createdAt,
    bookingId: bookingId,
    chatId: chatId,
  );
}
