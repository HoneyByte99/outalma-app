import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../shared/mode_badge.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';
import '../review/rating_summary.dart';
import '../../../l10n/app_localizations.dart';

class ProviderInboxPage extends ConsumerStatefulWidget {
  const ProviderInboxPage({super.key});

  @override
  ConsumerState<ProviderInboxPage> createState() => _ProviderInboxPageState();
}

class _ProviderInboxPageState extends ConsumerState<ProviderInboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            floating: true,
            backgroundColor: oc.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              l10n.inboxTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            actions: [
              const ModeBadge(),
              IconButton(
                onPressed: () => context.push(AppRoutes.providerCalendar),
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: l10n.inboxCalendarTooltip,
              ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: const Icon(Icons.inbox_outlined, size: 18),
                  text: l10n.inboxTabRequests,
                ),
                Tab(
                  icon: const Icon(Icons.hourglass_empty_outlined, size: 18),
                  text: l10n.inboxTabActive,
                ),
                Tab(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  text: l10n.inboxTabCompleted,
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [_RequestsTab(), _ActiveTab(), _CompletedTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: pending requests (status = requested)
// ---------------------------------------------------------------------------

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(providerInboxProvider);

    return inboxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          _ErrorState(onRetry: () => ref.invalidate(providerInboxProvider)),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _EmptyState(kind: _InboxEmptyKind.requests);
        }
        final sorted = [...bookings]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _InboxCard(booking: sorted[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: active bookings (status = accepted | in_progress)
// ---------------------------------------------------------------------------

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(providerActiveBookingsProvider);

    return activeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _ErrorState(
        onRetry: () => ref.invalidate(providerActiveBookingsProvider),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _EmptyState(kind: _InboxEmptyKind.active);
        }
        final sorted = [...bookings]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _InboxCard(booking: sorted[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: completed/terminal bookings (status = done | rejected | cancelled).
// `done` entries are where the provider leaves a review on the client.
// ---------------------------------------------------------------------------

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(providerCompletedBookingsProvider);

    return completedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _ErrorState(
        onRetry: () => ref.invalidate(providerCompletedBookingsProvider),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _EmptyState(kind: _InboxEmptyKind.completed);
        }
        // Most recent activity first (completed/cancelled at the top).
        final sorted = [...bookings]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _InboxCard(booking: sorted[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Booking card
// ---------------------------------------------------------------------------

class _InboxCard extends ConsumerWidget {
  const _InboxCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final serviceAsync = ref.watch(serviceDetailProvider(booking.serviceId));
    final serviceTitle = serviceAsync.valueOrNull?.title ?? '---';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.providerBookingDetail(booking.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: oc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: oc.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: oc.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        date_utils.formatAbsoluteDate(booking.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.secondaryText,
                        ),
                      ),
                      if (booking.scheduledAt != null)
                        Text(
                          l10n.bookingScheduledAt(
                            DateFormat(
                              'd MMM à HH:mm',
                              'fr_FR',
                            ).format(booking.scheduledAt!),
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: oc.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      // Client trust signal (rating + review count).
                      const SizedBox(height: 4),
                      RatingSummary(userId: booking.customerId),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(flex: 0, child: _StatusChip(status: booking.status)),
                Icon(Icons.chevron_right_rounded, color: oc.icons, size: 20),
              ],
            ),
            if (booking.requestMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                booking.requestMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: oc.secondaryText,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Explicit "More details" CTA → opens the booking detail (where the
            // chat, contact and review actions live). Clearer than a chat-only
            // shortcut and gives text-readers a labelled action even though the
            // whole card is also tappable.
            const SizedBox(height: 8),
            const Divider(height: 1),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.push(AppRoutes.providerBookingDetail(booking.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.read_more_rounded, size: 18, color: oc.primary),
                    const SizedBox(width: 6),
                    Text(
                      l10n.inboxMoreDetails,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: oc.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final (label, color) = switch (status) {
      BookingStatus.requested => (l10n.statusPending, oc.warning),
      BookingStatus.accepted => (l10n.statusAccepted, oc.primary),
      BookingStatus.inProgress => (l10n.statusInProgress, oc.statusInProgress),
      BookingStatus.done => (l10n.statusDone, oc.success),
      BookingStatus.rejected => (l10n.statusRejected, oc.secondaryText),
      BookingStatus.cancelled => (l10n.statusCancelled, oc.secondaryText),
      BookingStatus.unknown => ('—', oc.secondaryText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

enum _InboxEmptyKind { requests, active, completed }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final _InboxEmptyKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final (icon, title, subtitle) = switch (kind) {
      _InboxEmptyKind.requests => (
        Icons.inbox_outlined,
        l10n.inboxEmptyRequests,
        l10n.inboxEmptyRequestsSubtitle,
      ),
      _InboxEmptyKind.active => (
        Icons.hourglass_empty_outlined,
        l10n.inboxEmptyActive,
        l10n.inboxEmptyActiveSubtitle,
      ),
      _InboxEmptyKind.completed => (
        Icons.history_rounded,
        l10n.inboxEmptyCompleted,
        l10n.inboxEmptyCompletedSubtitle,
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: oc.icons),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              subtitle,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: oc.icons),
          const SizedBox(height: 12),
          Text(
            l10n.inboxLoadError,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}
