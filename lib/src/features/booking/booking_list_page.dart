import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.bookingsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.tabActive),
            Tab(text: l10n.tabDone),
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
        }).toList();

        if (filtered.isEmpty) {
          return _BookingListEmpty(isActive: isActive);
        }

        // Active tab: calendar + list. Done tab: simple list.
        if (isActive) {
          return _ActiveBookingsWithCalendar(bookings: filtered);
        }

        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _BookingCard(booking: filtered[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Active bookings with mini calendar
// ---------------------------------------------------------------------------

class _ActiveBookingsWithCalendar extends StatefulWidget {
  const _ActiveBookingsWithCalendar({required this.bookings});
  final List<Booking> bookings;

  @override
  State<_ActiveBookingsWithCalendar> createState() =>
      _ActiveBookingsWithCalendarState();
}

class _ActiveBookingsWithCalendarState
    extends State<_ActiveBookingsWithCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final oc = context.oc;

    // Filter by selected day if any
    var displayed = widget.bookings;
    if (_selectedDay != null) {
      displayed = displayed
          .where((b) =>
              b.scheduledAt != null && isSameDay(b.scheduledAt!, _selectedDay!))
          .toList();
    }
    // Sort by scheduledAt (upcoming first), fallback to createdAt
    displayed.sort((a, b) {
      final aDate = a.scheduledAt ?? a.createdAt;
      final bDate = b.scheduledAt ?? b.createdAt;
      return aDate.compareTo(bDate);
    });

    return CustomScrollView(
      slivers: [
        // Mini calendar
        SliverToBoxAdapter(
          child: TableCalendar<Booking>(
            locale: locale,
            calendarFormat: CalendarFormat.twoWeeks,
            availableCalendarFormats: const {
              CalendarFormat.twoWeeks: '2 sem.',
              CalendarFormat.month: 'Mois',
            },
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                // Tap same day again → deselect
                if (isSameDay(_selectedDay, selected)) {
                  _selectedDay = null;
                } else {
                  _selectedDay = selected;
                }
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) => _focusedDay = focused,
            eventLoader: (day) => widget.bookings
                .where((b) =>
                    b.scheduledAt != null && isSameDay(b.scheduledAt!, day))
                .toList(),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: oc.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: oc.primary),
              selectedDecoration: BoxDecoration(
                color: oc.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: oc.success,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: oc.border),
                borderRadius: BorderRadius.circular(12),
              ),
              titleTextStyle: Theme.of(context).textTheme.titleSmall!,
            ),
          ),
        ),

        // Selected day chip
        if (_selectedDay != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: oc.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: oc.primary),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEE d MMM', locale)
                              .format(_selectedDay!),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: oc.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedDay = null),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: oc.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close,
                                size: 12, color: oc.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Booking list
        if (displayed.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _selectedDay != null
                      ? l10n.bookingNoDateToday
                      : l10n.bookingNoUpcoming,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: oc.secondaryText),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList.separated(
              itemCount: displayed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _BookingCard(booking: displayed[i]),
            ),
          ),
      ],
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
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
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
              l10n.bookingRequestedAt(dateLabel),
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
                    l10n.bookingScheduledAt(DateFormat('d MMM, HH:mm', locale).format(booking.scheduledAt!)),
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
    final (label, color) = _statusStyle(context, status, oc);
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

  (String, Color) _statusStyle(BuildContext context, BookingStatus s, OutalmaColors oc) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case BookingStatus.requested:
        return (l10n.statusPending, oc.warning);
      case BookingStatus.accepted:
        return (l10n.statusAccepted, oc.primary);
      case BookingStatus.inProgress:
        return (l10n.statusInProgress, const Color(0xFF7B2FBE));
      case BookingStatus.done:
        return (l10n.statusDone, oc.success);
      case BookingStatus.rejected:
        return (l10n.statusRejected, oc.secondaryText);
      case BookingStatus.cancelled:
        return (l10n.statusCancelled, oc.secondaryText);
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
    final l10n = AppLocalizations.of(context)!;
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
                  ? l10n.bookingsActiveEmpty
                  : l10n.bookingsDoneEmpty,
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_outlined, size: 56, color: oc.icons),
          const SizedBox(height: 16),
          Text(
            l10n.errorLoading,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
