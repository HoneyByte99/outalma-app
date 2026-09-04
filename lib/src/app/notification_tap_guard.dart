import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../application/notification/notification_providers.dart';
import 'app_theme.dart';

/// Whether the chat/booking target named by a system notification's FCM
/// [data] payload still exists. Extracts chatId/bookingId the same way
/// [notificationRouteForData] does (empty strings don't count as an id), then
/// delegates the chat-wins-over-booking precedence to [notificationTargetExists]
/// itself rather than re-implementing it here.
Future<bool> notificationTargetExistsForData({
  required FirebaseFirestore db,
  required Map<String, dynamic> data,
}) {
  final chatId = data['chatId'] as String?;
  final bookingId = data['bookingId'] as String?;
  return notificationTargetExists(
    db: db,
    chatId: (chatId != null && chatId.isNotEmpty) ? chatId : null,
    bookingId: (bookingId != null && bookingId.isNotEmpty) ? bookingId : null,
  );
}

/// Shows the same "target gone" message as the notifications list
/// (`l10n.notificationTargetGone`) via [messengerKey], for the cold-start /
/// background tap path where the widget has no local BuildContext at the
/// point the existence check completes. [messengerKey]'s state sits below
/// the app's [Localizations] widget (it's built inside MaterialApp itself),
/// so its own context resolves l10n correctly.
void showNotificationTargetGoneMessage(
  GlobalKey<ScaffoldMessengerState> messengerKey,
) {
  final state = messengerKey.currentState;
  if (state == null) return;
  final l10n = AppLocalizations.of(state.context);
  if (l10n == null) return;
  state.showSnackBar(
    SnackBar(
      content: Text(l10n.notificationTargetGone),
      backgroundColor: state.context.oc.error,
    ),
  );
}
