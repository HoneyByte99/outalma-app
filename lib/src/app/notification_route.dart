import 'router.dart';

/// Resolves the in-app route to open when a push notification is tapped, from
/// its FCM `data` payload. Returns null when the payload carries no recognizable
/// target (so the tap just opens the app on its current screen).
///
/// A chat deep-link wins over a booking one when both are present (a chat
/// message is the more specific destination). Pure and unit-tested in isolation
/// so the routing rules can't silently drift.
String? notificationRouteForData(Map<String, dynamic> data) {
  final chatId = data['chatId'] as String?;
  if (chatId != null && chatId.isNotEmpty) return AppRoutes.chat(chatId);

  final bookingId = data['bookingId'] as String?;
  if (bookingId != null && bookingId.isNotEmpty) {
    return AppRoutes.bookingDetail(bookingId);
  }

  return null;
}
