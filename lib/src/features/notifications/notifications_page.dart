import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/notification/notification_providers.dart';
import '../../application/user/user_providers.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/models/app_notification.dart';
import '../../../l10n/app_localizations.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  // Selected tab; defaults to the active app mode so the user lands on the role
  // they're currently operating as.
  late ActiveMode _tab;

  @override
  void initState() {
    super.initState();
    _tab = ref.read(activeModeProvider);
  }

  /// Whether a notification belongs in [tab]. `both` (ambiguous legacy notifs)
  /// appear under both tabs so nothing is ever hidden.
  bool _inTab(AppNotification n, ActiveMode tab) {
    final a = notificationAudienceOf(n);
    if (a == NotificationAudience.both) return true;
    return tab == ActiveMode.client
        ? a == NotificationAudience.client
        : a == NotificationAudience.provider;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final notifAsync = ref.watch(notificationsProvider);
    final db = ref.read(firestoreProvider);
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final uid = authState is AuthAuthenticated ? authState.user.id : null;
    final tab = _tab;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          notifAsync.maybeWhen(
            data: (list) {
              // "Mark all read" acts on the visible tab only.
              final visible = list.where((n) => _inTab(n, tab)).toList();
              final hasUnread = visible.any((n) => !n.read);
              if (!hasUnread || uid == null) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => markAllNotificationsRead(
                  db: db,
                  uid: uid,
                  notifications: visible,
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
                Icon(Icons.wifi_off_outlined, size: 56, color: oc.icons),
                const SizedBox(height: 16),
                Text(
                  l10n.notificationsError,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(notificationsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (all) {
          final clientUnread = all
              .where((n) => !n.read && _inTab(n, ActiveMode.client))
              .length;
          final providerUnread = all
              .where((n) => !n.read && _inTab(n, ActiveMode.provider))
              .length;
          final list = all.where((n) => _inTab(n, tab)).toList();

          return Column(
            children: [
              _AudienceTabs(
                selected: tab,
                clientUnread: clientUnread,
                providerUnread: providerUnread,
                onSelect: (m) => setState(() => _tab = m),
              ),
              Expanded(
                child: list.isEmpty
                    ? _EmptyNotifications()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72, endIndent: 16),
                        itemBuilder: (context, i) {
                          final notif = list[i];
                          return _NotificationTile(
                            notification: notif,
                            uid: uid,
                            db: db,
                            onTap: () => _handleTap(context, notif, uid, ref),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    AppNotification notif,
    String? uid,
    WidgetRef ref,
  ) async {
    if (uid != null && !notif.read) {
      unawaited(
        markNotificationRead(
          db: ref.read(firestoreProvider),
          uid: uid,
          notifId: notif.id,
        ),
      );
    }

    // Open the notification in the role it concerns: a provider-audience
    // notification switches to provider mode (and vice versa) so the deep-link
    // target lands in the right mode/tab. Ambiguous audiences leave mode as-is.
    final targetMode = activeModeForAudience(notificationAudienceOf(notif));
    if (targetMode != null && ref.read(activeModeProvider) != targetMode) {
      await ref.read(authNotifierProvider.notifier).switchMode(targetMode);
    }
    if (!context.mounted) return;

    if (notif.chatId != null) {
      unawaited(context.push(AppRoutes.chat(notif.chatId!)));
    } else if (notif.bookingId != null) {
      unawaited(context.push(AppRoutes.bookingDeepLink(notif.bookingId!)));
    }
  }
}

// ---------------------------------------------------------------------------
// Client / Provider segmented tabs
// ---------------------------------------------------------------------------

class _AudienceTabs extends StatelessWidget {
  const _AudienceTabs({
    required this.selected,
    required this.clientUnread,
    required this.providerUnread,
    required this.onSelect,
  });

  final ActiveMode selected;
  final int clientUnread;
  final int providerUnread;
  final ValueChanged<ActiveMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Container(
      color: oc.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: oc.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _Segment(
              icon: Icons.person_outline_rounded,
              label: l10n.modeClient,
              unread: clientUnread,
              isSelected: selected == ActiveMode.client,
              onTap: () => onSelect(ActiveMode.client),
            ),
            _Segment(
              icon: Icons.handyman_outlined,
              label: l10n.modeProvider,
              unread: providerUnread,
              isSelected: selected == ActiveMode.provider,
              onTap: () => onSelect(ActiveMode.provider),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.unread,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int unread;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final fg = isSelected ? oc.primary : oc.secondaryText;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: unread > 0
            ? '$label, ${l10n.notificationsUnreadCount(unread)}'
            : label,
        // Selected pill: a fill alone is near-invisible against the track in
        // dark mode, so add elevation + a border as the primary affordance.
        child: Material(
          color: isSelected ? oc.surface : Colors.transparent,
          elevation: isSelected ? 1 : 0,
          shadowColor: oc.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: isSelected ? BorderSide(color: oc.border) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: oc.primary,
                        borderRadius: BorderRadius.circular(999),
                        // White stroke so the count pops off both the selected
                        // surface and the track (the pill fill == primary).
                        border: Border.all(color: oc.surface, width: 1.5),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          // Pairs with the oc.primary fill in both themes
                          // (light: light-on-navy, dark: dark-on-mint).
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    if (diff.inMinutes < 60) {
      return l10n.notificationTimeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) return l10n.notificationTimeHours(diff.inHours);
    if (diff.inDays == 1) return l10n.notificationTimeYesterday;
    if (diff.inDays < 7) return l10n.notificationTimeDays(diff.inDays);
    // Locale-aware numeric date (fr → d/M/y, en → M/d/y) instead of a hardcoded
    // order.
    return DateFormat.yMd(l10n.localeName).format(dt);
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
                color: _iconColor(
                  notification.type,
                  oc,
                ).withValues(alpha: 0.12),
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
                          style: Theme.of(context).textTheme.bodyMedium
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
            Icon(Icons.notifications_none_rounded, size: 56, color: oc.icons),
            const SizedBox(height: 16),
            Text(
              l10n.notificationsEmpty,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.notificationsEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
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
