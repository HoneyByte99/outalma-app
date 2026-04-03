import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';

class BookingListPage extends ConsumerStatefulWidget {
  const BookingListPage({super.key});

  @override
  ConsumerState<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends ConsumerState<BookingListPage>
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
      appBar: AppBar(
        title: const Text('Mes réservations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En cours'),
            Tab(text: 'Terminées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BookingTab(isActive: true),
          _BookingTab(isActive: false),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab content
// ---------------------------------------------------------------------------

class _BookingTab extends ConsumerWidget {
  const _BookingTab({required this.isActive});

  final bool isActive;

  static const _activeStatuses = {
    BookingStatus.requested,
    BookingStatus.accepted,
    BookingStatus.inProgress,
  };

  static const _doneStatuses = {
    BookingStatus.done,
    BookingStatus.rejected,
    BookingStatus.cancelled,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(customerBookingsProvider);

    return bookingsAsync.when(
      loading: () => const _BookingListLoading(),
      error: (_, __) => _BookingListError(
        onRetry: () => ref.invalidate(customerBookingsProvider),
      ),
      data: (bookings) {
        final filtered = bookings.where((b) {
          return isActive
              ? _activeStatuses.contains(b.status)
              : _doneStatuses.contains(b.status);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (filtered.isEmpty) {
          return _BookingListEmpty(isActive: isActive);
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            return _BookingCard(booking: filtered[i]);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Booking card
// ---------------------------------------------------------------------------

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final serviceAsync =
        ref.watch(serviceDetailProvider(booking.serviceId));

    final serviceTitle = serviceAsync.valueOrNull?.title ?? '---';
    final dateLabel = _formatDate(booking.createdAt);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.bookingDetail(booking.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: oc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: oc.border),
          boxShadow: [
            BoxShadow(
              color: oc.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    serviceTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Demande du $dateLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.secondaryText,
                  ),
            ),
            if (booking.scheduledAt != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: oc.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Pr\u00e9vu : ${DateFormat('d MMM \u00e0 HH:mm', 'fr_FR').format(booking.scheduledAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: oc.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ],
            if (booking.requestMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                booking.requestMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.secondaryText,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date formatting helper (no intl dependency)
// ---------------------------------------------------------------------------

String _formatDate(DateTime dt) {
  const months = [
    'jan',
    'fév',
    'mars',
    'avr',
    'mai',
    'juin',
    'juil',
    'août',
    'sep',
    'oct',
    'nov',
    'déc',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
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
    final (label, color) = _statusStyle(status, oc);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  (String, Color) _statusStyle(BookingStatus s, OutalmaColors oc) {
    switch (s) {
      case BookingStatus.requested:
        return ('En attente', oc.warning);
      case BookingStatus.accepted:
        return ('Acceptée', oc.primary);
      case BookingStatus.inProgress:
        return ('En cours', const Color(0xFF7B2FBE));
      case BookingStatus.done:
        return ('Terminée', oc.success);
      case BookingStatus.rejected:
        return ('Refusée', oc.secondaryText);
      case BookingStatus.cancelled:
        return ('Annulée', oc.secondaryText);
    }
  }
}

// ---------------------------------------------------------------------------
// Loading state
// ---------------------------------------------------------------------------

class _BookingListLoading extends StatelessWidget {
  const _BookingListLoading();

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: oc.border,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

class _BookingListEmpty extends StatelessWidget {
  const _BookingListEmpty({required this.isActive});

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
                  ? Icons.calendar_today_outlined
                  : Icons.history_outlined,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? 'Aucune réservation en cours'
                  : 'Aucune réservation terminée',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: oc.secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingListError extends StatelessWidget {
  const _BookingListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_outlined, size: 56, color: oc.icons),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
