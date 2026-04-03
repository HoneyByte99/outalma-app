import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'Missions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            actions: [
              IconButton(
                onPressed: () => context.push(AppRoutes.providerCalendar),
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Mon calendrier',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Demandes'),
                Tab(text: 'En cours'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _RequestsTab(),
            _ActiveTab(),
          ],
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
      error: (_, __) => const _ErrorState(),
      data: (bookings) {
        if (bookings.isEmpty) return const _EmptyState(isActive: false);
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
      error: (_, __) => const _ErrorState(),
      data: (bookings) {
        if (bookings.isEmpty) return const _EmptyState(isActive: true);
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
    final oc = context.oc;
    final serviceAsync = ref.watch(serviceDetailProvider(booking.serviceId));
    final serviceTitle = serviceAsync.valueOrNull?.title ?? '---';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.providerBookingDetail(booking.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: oc.surface,
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
                        _formatDate(booking.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: oc.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: booking.status),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: oc.icons,
                  size: 20,
                ),
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
            // Chat shortcut for accepted/in_progress bookings
            if (booking.chatId != null &&
                (booking.status == BookingStatus.accepted ||
                    booking.status == BookingStatus.inProgress)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push(AppRoutes.chat(booking.chatId!)),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: oc.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ouvrir le chat',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: oc.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
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
    final oc = context.oc;
    final (label, color) = switch (status) {
      BookingStatus.requested => ('En attente', oc.warning),
      BookingStatus.accepted => ('Acceptée', oc.primary),
      BookingStatus.inProgress => ('En cours', const Color(0xFF7B2FBE)),
      BookingStatus.done => ('Terminée', oc.success),
      BookingStatus.rejected => ('Refusée', oc.secondaryText),
      BookingStatus.cancelled => ('Annulée', oc.secondaryText),
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
// Helpers
// ---------------------------------------------------------------------------

String _formatDate(DateTime dt) {
  const months = [
    'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive
                  ? Icons.hourglass_empty_outlined
                  : Icons.inbox_outlined,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? 'Aucune mission en cours'
                  : 'Aucune demande en attente',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Les missions acceptées apparaîtront ici.'
                  : 'Les nouvelles demandes clients apparaîtront ici.',
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

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Impossible de charger les données.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: context.oc.secondaryText),
      ),
    );
  }
}
