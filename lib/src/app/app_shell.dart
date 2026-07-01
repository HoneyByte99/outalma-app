import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth/auth_providers.dart';
import '../application/auth/auth_state.dart';
import '../application/booking/booking_providers.dart';
import '../application/notification/notification_providers.dart';
import '../application/provider/provider_providers.dart';
import '../application/user/user_providers.dart';
import '../domain/enums/active_mode.dart';
import '../features/auth/auth_prompt.dart';
import '../features/shared/open_settings.dart';
import '../../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'router.dart';

/// Shell scaffold with mode-aware bottom navigation.
///
/// Client mode   → Tab 0: Accueil | Tab 1: Réservations | Tab 2: Chats | Tab 3: Profil
/// Provider mode → Tab 0: Dashboard | Tab 1: Missions | Tab 2: Chats | Tab 3: Profil
///
/// Branch layout in the router:
///   0 = client home, 1 = client bookings,
///   2 = provider dashboard, 3 = provider inbox,
///   4 = chats (shared), 5 = profile (shared)
///
/// Logical tab → branch index mapping:
///   Client:   0→0, 1→1, 2→4, 3→5
///   Provider: 0→2, 1→3, 2→4, 3→5
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Maps logical tab index to router branch index per mode.
  static const _clientBranches = [0, 1, 4, 5];
  static const _providerBranches = [2, 3, 4, 5];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns to the app - typically right after toggling
    // notifications on in iOS Settings via our banner - re-run token
    // registration (so a now-granted permission finally yields a pushToken)
    // and refresh the permission status that drives the banner.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationInitProvider);
      ref.invalidate(notificationPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    ref.watch(notificationInitProvider);

    final l10n = AppLocalizations.of(context)!;
    final isProvider = ref.watch(activeModeProvider) == ActiveMode.provider;
    final isGuest =
        ref.watch(authNotifierProvider).valueOrNull is! AuthAuthenticated;
    final branches = isProvider
        ? AppShell._providerBranches
        : AppShell._clientBranches;

    // Find which logical tab corresponds to the current branch.
    final currentBranch = shell.currentIndex;
    final currentLogical = branches.indexOf(currentBranch).clamp(0, 3);

    void onTap(int logicalIndex) {
      HapticFeedback.selectionClick();
      // A guest may only use Home (logical 0); the other tabs are login-gated.
      // Offer the auth prompt, returning to Home after sign-in.
      if (isGuest && logicalIndex != 0) {
        showAuthPrompt(
          context,
          reason: l10n.guestLockedTabLogin,
          redirect: AppRoutes.home,
        );
        return;
      }
      final branchIndex = branches[logicalIndex];
      shell.goBranch(
        branchIndex,
        initialLocation: branchIndex == shell.currentIndex,
      );
    }

    // Badge counts
    final providerInboxCount =
        ref.watch(providerInboxProvider).valueOrNull?.length ?? 0;
    final clientActiveCount = ref.watch(clientActiveBookingsCountProvider);

    final destinations = isProvider
        ? _providerDestinations(l10n, providerInboxCount)
        : _clientDestinations(l10n, clientActiveCount);

    final oc = context.oc;
    final accent = isProvider ? oc.success : oc.primary;

    // Material 3 NavigationBar (A.7): cleaner active state via a pill
    // indicator behind the selected icon, smoother transitions, better
    // dark-mode contrast than the legacy BottomNavigationBar.
    // Non-blocking banner when OS notifications are off. iOS only shows the
    // permission prompt once, so without this a single "Don't Allow" silently
    // kills push forever - the root cause of "others don't receive notifs".
    final notifStatus = ref.watch(notificationPermissionProvider).valueOrNull;
    // Only for `denied` - `notDetermined` means initialize() is about to fire
    // the OS prompt, so a banner then would be premature and misleading.
    final showNotifBanner = notifStatus == AuthorizationStatus.denied;

    return Scaffold(
      body: Column(
        children: [
          if (showNotifBanner)
            SafeArea(bottom: false, child: _NotifDisabledBanner(l10n: l10n)),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: oc.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: oc.shadow,
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: oc.surface,
            indicatorColor: accent.withValues(alpha: 0.16),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? accent : oc.icons,
                size: 22,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? accent : oc.secondaryText,
                letterSpacing: 0.1,
              );
            }),
            surfaceTintColor: Colors.transparent,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
          child: NavigationBar(
            selectedIndex: currentLogical,
            onDestinationSelected: onTap,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav item builders with badge support
// ---------------------------------------------------------------------------

List<NavigationDestination> _clientDestinations(
  AppLocalizations l10n,
  int activeCount,
) {
  return [
    NavigationDestination(
      icon: const Icon(Icons.home_outlined),
      selectedIcon: const Icon(Icons.home_rounded),
      label: l10n.navHome,
    ),
    NavigationDestination(
      icon: _BadgedIcon(
        count: activeCount,
        icon: Icons.calendar_today_outlined,
      ),
      selectedIcon: _BadgedIcon(
        count: activeCount,
        icon: Icons.calendar_today_rounded,
      ),
      label: l10n.navBookings,
    ),
    NavigationDestination(
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: const Icon(Icons.chat_bubble_rounded),
      label: l10n.navChats,
    ),
    NavigationDestination(
      icon: const Icon(Icons.person_outline_rounded),
      selectedIcon: const Icon(Icons.person_rounded),
      label: l10n.navProfile,
    ),
  ];
}

List<NavigationDestination> _providerDestinations(
  AppLocalizations l10n,
  int inboxCount,
) {
  return [
    NavigationDestination(
      icon: const Icon(Icons.dashboard_outlined),
      selectedIcon: const Icon(Icons.dashboard_rounded),
      label: l10n.navDashboard,
    ),
    NavigationDestination(
      icon: _BadgedIcon(count: inboxCount, icon: Icons.inbox_outlined),
      selectedIcon: _BadgedIcon(count: inboxCount, icon: Icons.inbox_rounded),
      label: l10n.navMissions,
    ),
    NavigationDestination(
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: const Icon(Icons.chat_bubble_rounded),
      label: l10n.navChats,
    ),
    NavigationDestination(
      icon: const Icon(Icons.person_outline_rounded),
      selectedIcon: const Icon(Icons.person_rounded),
      label: l10n.navProfile,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Notifications-disabled banner → deep-link to iOS Settings
// ---------------------------------------------------------------------------

class _NotifDisabledBanner extends StatelessWidget {
  const _NotifDisabledBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    // Amber "warning" reads as "needs attention" (not error) and stays visible
    // in sunlight, unlike the near-white primary tint. Combined accessible
    // label so screen readers announce the whole row as one Settings button.
    return Semantics(
      button: true,
      label: '${l10n.notifDisabledBanner} ${l10n.notifEnableAction}',
      onTap: openAppSettings,
      child: Material(
        color: oc.warning.withValues(alpha: 0.15),
        child: InkWell(
          onTap: openAppSettings,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: oc.border)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  color: oc.warning,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.notifDisabledBanner,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Pill button - the app's standard CTA shape, instantly read as
                // tappable even by users who don't read the label.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: oc.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.notifEnableAction,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable badged icon widget
// ---------------------------------------------------------------------------

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.count, required this.icon});

  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count', style: const TextStyle(fontSize: 10)),
      child: Icon(icon),
    );
  }
}

// ---------------------------------------------------------------------------
// Bell icon button - reusable across AppBar actions
// ---------------------------------------------------------------------------

class BellIconButton extends ConsumerWidget {
  const BellIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    return IconButton(
      tooltip: l10n.tooltipNotifications,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
