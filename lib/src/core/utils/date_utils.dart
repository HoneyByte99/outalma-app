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
