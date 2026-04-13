import 'package:flutter/material.dart';
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

    final items = isProvider
        ? _providerNavItems(l10n, providerInboxCount)
        : _clientNavItems(l10n, clientActiveCount);

    final oc = context.oc;

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
        child: BottomNavigationBar(
          currentIndex: currentLogical,
          onTap: onTap,
          backgroundColor: oc.surface,
          selectedItemColor: isProvider ? oc.success : oc.primary,
          unselectedItemColor: oc.icons,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: items,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav item builders with badge support
// ---------------------------------------------------------------------------

List<BottomNavigationBarItem> _clientNavItems(
    AppLocalizations l10n, int activeCount) {
  return [
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      activeIcon: const Icon(Icons.home_rounded),
      label: l10n.navHome,
    ),
    BottomNavigationBarItem(
      icon: _BadgedIcon(count: activeCount, icon: Icons.calendar_today_outlined),
      activeIcon: _BadgedIcon(count: activeCount, icon: Icons.calendar_today_rounded),
      label: l10n.navBookings,
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      activeIcon: const Icon(Icons.chat_bubble_rounded),
      label: l10n.navChats,
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person_outline_rounded),
      activeIcon: const Icon(Icons.person_rounded),
      label: l10n.navProfile,
    ),
  ];
}

List<BottomNavigationBarItem> _providerNavItems(
    AppLocalizations l10n, int inboxCount) {
  return [
    BottomNavigationBarItem(
      icon: const Icon(Icons.dashboard_outlined),
      activeIcon: const Icon(Icons.dashboard_rounded),
      label: l10n.navDashboard,
    ),
    BottomNavigationBarItem(
      icon: _BadgedIcon(count: inboxCount, icon: Icons.inbox_outlined),
      activeIcon: _BadgedIcon(count: inboxCount, icon: Icons.inbox_rounded),
      label: l10n.navMissions,
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      activeIcon: const Icon(Icons.chat_bubble_rounded),
      label: l10n.navChats,
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person_outline_rounded),
      activeIcon: const Icon(Icons.person_rounded),
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
