import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/notification/notification_providers.dart';
import '../../domain/models/app_notification.dart';
import '../../../l10n/app_localizations.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final notifAsync = ref.watch(notificationsProvider);
    final db = ref.read(firestoreProvider);
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final uid =
        authState is AuthAuthenticated ? authState.user.id : null;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          notifAsync.maybeWhen(
            data: (list) {
              final hasUnread = list.any((n) => !n.read);
              if (!hasUnread || uid == null) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => markAllNotificationsRead(
                  db: db,
                  uid: uid,
                  notifications: list,
                ),
                child: Text(l10n.notificationsReadAll),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_outlined,
                  size: 56,
                  color: oc.icons,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.notificationsError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: oc.secondaryText),
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyNotifications();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, i) {
              final notif = notifications[i];
              return _NotificationTile(
                notification: notif,
                uid: uid,
                db: ref.read(firestoreProvider),
                onTap: () => _handleTap(context, notif, uid, ref),
              );
            },
          );
        },
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    AppNotification notif,
    String? uid,
    WidgetRef ref,
  ) {
    if (uid != null && !notif.read) {
      markNotificationRead(
        db: ref.read(firestoreProvider),
        uid: uid,
        notifId: notif.id,
      );
    }

    if (notif.chatId != null) {
      context.push(AppRoutes.chat(notif.chatId!));
    } else if (notif.bookingId != null) {
      context.push(AppRoutes.bookingDeepLink(notif.bookingId!));
    }
  }
}

// ---------------------------------------------------------------------------
// Notification tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.uid,
    required this.db,
    required this.onTap,
  });

  final AppNotification notification;
  final String? uid;
  final dynamic db;
  final VoidCallback onTap;

  String _relativeTime(DateTime dt, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return l10n.notificationTimeNow;
    if (diff.inMinutes < 60) return l10n.notificationTimeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.notificationTimeHours(diff.inHours);
    if (diff.inDays == 1) return l10n.notificationTimeYesterday;
    if (diff.inDays < 7) return l10n.notificationTimeDays(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final isUnread = !notification.read;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread
            ? oc.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor(notification.type, oc).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _notifIcon(notification.type),
                size: 22,
                color: _iconColor(notification.type, oc),
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: oc.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification.createdAt, l10n),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: oc.icons,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.notificationsEmpty,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.notificationsEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: oc.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IconData _notifIcon(String type) {
  return switch (type) {
    'booking_accepted' => Icons.check_circle_outline_rounded,
    'booking_rejected' => Icons.cancel_outlined,
    'booking_in_progress' => Icons.play_circle_outline_rounded,
    'booking_done' => Icons.verified_outlined,
    'new_message' => Icons.chat_bubble_outline_rounded,
    _ => Icons.notifications_outlined,
  };
}

Color _iconColor(String type, OutalmaColors oc) {
  return switch (type) {
    'booking_accepted' => oc.success,
    'booking_rejected' => oc.error,
    'booking_in_progress' => oc.warning,
    'booking_done' => oc.success,
    'new_message' => oc.primary,
    _ => oc.icons,
  };
}
