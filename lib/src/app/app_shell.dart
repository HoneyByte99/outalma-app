import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth/auth_providers.dart';
import '../application/booking/booking_providers.dart';
import '../application/notification/notification_providers.dart';
import '../application/provider/provider_providers.dart';
import '../application/user/user_providers.dart';
import '../domain/enums/active_mode.dart';
import '../../l10n/app_localizations.dart';
import 'app_theme.dart';

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
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Maps logical tab index to router branch index per mode.
  static const _clientBranches = [0, 1, 4, 5];
  static const _providerBranches = [2, 3, 4, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationInitProvider);

    final l10n = AppLocalizations.of(context)!;
    final isProvider = ref.watch(activeModeProvider) == ActiveMode.provider;
    final branches = isProvider ? _providerBranches : _clientBranches;

    // Find which logical tab corresponds to the current branch.
    final currentBranch = shell.currentIndex;
    final currentLogical = branches.indexOf(currentBranch).clamp(0, 3);

    void onTap(int logicalIndex) {
      HapticFeedback.selectionClick();
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
    return Scaffold(
      body: shell,
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
// Bell icon button — reusable across AppBar actions
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
