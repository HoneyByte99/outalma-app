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
    this.audience,
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

  /// Which role this notification is meant for: 'client' or 'provider'. Set by
  /// the Cloud Function that knows the recipient's role for this event. Older
  /// notifications predate the field (null) — see [notificationAudienceOf] for
  /// the inference fallback that keeps them visible.
  final String? audience;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    read: read ?? this.read,
    createdAt: createdAt,
    bookingId: bookingId,
    chatId: chatId,
    audience: audience,
  );
}

/// Audience buckets for the notifications screen tabs.
enum NotificationAudience { client, provider, both }

/// Resolves which tab(s) a notification belongs to. Prefers the explicit
/// `audience` written by the server; falls back to inferring from `type` for
/// legacy notifications so none are ever hidden (ambiguous ones show in both).
NotificationAudience notificationAudienceOf(AppNotification n) {
  switch (n.audience) {
    case 'client':
      return NotificationAudience.client;
    case 'provider':
      return NotificationAudience.provider;
  }
  switch (n.type) {
    case 'booking_requested':
      return NotificationAudience.provider;
    case 'booking_accepted':
    case 'booking_rejected':
    case 'booking_in_progress':
      return NotificationAudience.client;
    default:
      // booking_done / booking_cancelled / new_message / booking_reminder and
      // anything unknown: role can't be told from type alone → show in both.
      return NotificationAudience.both;
  }
}
