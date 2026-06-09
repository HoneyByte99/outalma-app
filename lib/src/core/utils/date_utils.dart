import 'package:intl/intl.dart';

/// Returns a human-readable relative time string.
/// Falls back to absolute date for older timestamps.
String formatRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'maintenant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return DateFormat('EEEE', 'fr').format(dt);
  return DateFormat('d MMM', 'fr').format(dt);
}

String formatAbsoluteDate(DateTime dt) =>
    DateFormat('d MMM yyyy', 'fr').format(dt);

String formatAbsoluteDateTime(DateTime dt) =>
    DateFormat('d MMM, HH:mm', 'fr').format(dt);

String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

/// Label for a chat day separator: "Today" / "Yesterday" (passed in,
/// localized by the caller) for recent days, the weekday name within the
/// last week, otherwise an absolute date.
String formatChatDaySeparator(
  DateTime dt, {
  required String today,
  required String yesterday,
}) {
  final now = DateTime.now();
  final day = DateTime(dt.year, dt.month, dt.day);
  final todayDay = DateTime(now.year, now.month, now.day);
  final diffDays = todayDay.difference(day).inDays;
  if (diffDays <= 0) return today;
  if (diffDays == 1) return yesterday;
  if (diffDays < 7) return DateFormat('EEEE', 'fr').format(dt);
  return DateFormat('d MMMM yyyy', 'fr').format(dt);
}

/// True when [a] and [b] fall on different calendar days.
bool isDifferentDay(DateTime a, DateTime b) =>
    a.year != b.year || a.month != b.month || a.day != b.day;
