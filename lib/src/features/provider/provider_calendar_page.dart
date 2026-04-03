import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/provider/provider_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../application/service/service_providers.dart';
import '../../domain/models/blocked_slot.dart';
import '../../domain/models/booking.dart';

class ProviderCalendarPage extends ConsumerStatefulWidget {
  const ProviderCalendarPage({super.key});

  @override
  ConsumerState<ProviderCalendarPage> createState() =>
      _ProviderCalendarPageState();
}

class _ProviderCalendarPageState
    extends ConsumerState<ProviderCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bookings = ref.watch(providerBookingHistoryProvider).valueOrNull ?? [];
    final blockedSlots = ref.watch(providerBlockedSlotsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: const Text('Mon calendrier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBlockSlotSheet(context),
        backgroundColor: oc.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.block_outlined, size: 20),
        label: const Text('Bloquer un créneau'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TableCalendar<Object>(
            locale: 'fr_FR',
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Mois'},
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) => _focusedDay = focused,
            eventLoader: (day) => _eventsForDay(day, bookings, blockedSlots),
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
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: Theme.of(context).textTheme.titleSmall!,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final hasBooking = events.any((e) => e is Booking);
                final hasBlocked = events.any((e) => e is BlockedSlot);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasBooking)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: oc.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasBlocked)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: oc.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                );
              },
            ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),

          // Legend
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _LegendDot(color: oc.primary, label: 'RDV'),
                  const SizedBox(width: 16),
                  _LegendDot(color: oc.error, label: 'Indisponible'),
                ],
              ),
            ),
          ),

          // Day selection chip — tap X to clear and show all upcoming
          if (_selectedDay != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                            DateFormat('EEE d MMM', 'fr_FR')
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
                            onTap: () =>
                                setState(() => _selectedDay = null),
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

          // Day detail OR upcoming bookings — not both
          if (_selectedDay != null)
            _DayDetailSliver(
              day: _selectedDay!,
              bookings: bookings,
              blockedSlots: blockedSlots,
            )
          else
            _UpcomingBookingsSliver(bookings: bookings),
        ],
      ),
    );
  }

  List<Object> _eventsForDay(
    DateTime day,
    List<Booking> bookings,
    List<BlockedSlot> slots,
  ) {
    final events = <Object>[];
    for (final b in bookings) {
      if (b.scheduledAt != null && isSameDay(b.scheduledAt!, day)) {
        events.add(b);
      }
    }
    for (final s in slots) {
      if (isSameDay(s.date, day)) {
        events.add(s);
      } else if (s.endDate != null &&
          day.isAfter(s.date.subtract(const Duration(days: 1))) &&
          day.isBefore(s.endDate!.add(const Duration(days: 1)))) {
        events.add(s);
      }
    }
    return events;
  }

  Future<void> _showBlockSlotSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.oc.error;
    final result = await showModalBottomSheet<BlockedSlot>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BlockSlotSheet(initialDate: _selectedDay),
    );
    if (result != null && mounted) {
      final authState = ref.read(authNotifierProvider).valueOrNull;
      if (authState is AuthAuthenticated) {
        try {
          await ref
              .read(providerRepositoryProvider)
              .addBlockedSlot(authState.user.id, result);
          // Invalidate stream + nudge focusedDay to force TableCalendar
          // to re-run eventLoader for the current month.
          ref.invalidate(providerBlockedSlotsProvider);
          if (mounted) {
            final saved = _focusedDay;
            setState(() => _focusedDay = saved.add(const Duration(days: 32)));
            await Future<void>.delayed(const Duration(milliseconds: 50));
            if (mounted) setState(() => _focusedDay = saved);
          }
          messenger.showSnackBar(
            const SnackBar(content: Text('Cr\u00e9neau bloqu\u00e9')),
          );
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Impossible de bloquer le cr\u00e9neau.'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Day detail — shows bookings + blocked slots for selected day
// ---------------------------------------------------------------------------

class _DayDetailSliver extends ConsumerWidget {
  const _DayDetailSliver({
    required this.day,
    required this.bookings,
    required this.blockedSlots,
  });

  final DateTime day;
  final List<Booking> bookings;
  final List<BlockedSlot> blockedSlots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final dayBookings = bookings.where((b) {
      return b.scheduledAt != null && isSameDay(b.scheduledAt!, day);
    }).toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    final daySlots = blockedSlots.where((s) {
      if (isSameDay(s.date, day)) return true;
      if (s.endDate != null &&
          day.isAfter(s.date.subtract(const Duration(days: 1))) &&
          day.isBefore(s.endDate!.add(const Duration(days: 1)))) {
        return true;
      }
      return false;
    }).toList();

    if (dayBookings.isEmpty && daySlots.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 20, color: oc.icons),
              const SizedBox(width: 8),
              Text(
                'Aucun RDV ce jour',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: oc.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final items = <Widget>[
      for (final b in dayBookings) _BookingTile(booking: b),
      for (final s in daySlots)
        _BlockedSlotTile(
          slot: s,
          onDelete: () {
            final authState =
                ref.read(authNotifierProvider).valueOrNull;
            if (authState is AuthAuthenticated) {
              ref
                  .read(providerRepositoryProvider)
                  .removeBlockedSlot(authState.user.id, s.id);
            }
          },
        ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming bookings — shown when no day is selected
// ---------------------------------------------------------------------------

class _UpcomingBookingsSliver extends StatelessWidget {
  const _UpcomingBookingsSliver({required this.bookings});
  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final now = DateTime.now();
    final upcoming = bookings
        .where((b) =>
            b.scheduledAt != null &&
            b.scheduledAt!.isAfter(now) &&
            (b.status == BookingStatus.accepted ||
                b.status == BookingStatus.inProgress ||
                b.status == BookingStatus.requested))
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    if (upcoming.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_outlined,
                  size: 48, color: oc.icons),
              const SizedBox(height: 12),
              Text(
                'Aucune r\u00e9servation \u00e0 venir',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: oc.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverList.builder(
        itemCount: upcoming.length + 1, // +1 for header
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'R\u00e9servations \u00e0 venir',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            );
          }
          return _UpcomingBookingTile(booking: upcoming[i - 1]);
        },
      ),
    );
  }
}

class _UpcomingBookingTile extends ConsumerWidget {
  const _UpcomingBookingTile({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final service =
        ref.watch(serviceDetailProvider(booking.serviceId)).valueOrNull;
    final dateFmt = DateFormat('EEE d MMM', 'fr_FR');
    final timeFmt = DateFormat('HH:mm', 'fr_FR');
    final dateStr = dateFmt.format(booking.scheduledAt!);
    final timeStr = timeFmt.format(booking.scheduledAt!);

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.bookingDeepLink(booking.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: oc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: oc.border),
        ),
        child: Row(
          children: [
            // Date column
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: oc.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    dateStr.split(' ').first.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: oc.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    booking.scheduledAt!.day.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: oc.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service?.title ?? 'Service',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\u00e0 $timeStr',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: oc.secondaryText),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: oc.icons),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final service =
        ref.watch(serviceDetailProvider(booking.serviceId)).valueOrNull;
    final timeFmt = DateFormat('HH:mm', 'fr_FR');
    final timeStr = booking.scheduledAt != null
        ? timeFmt.format(booking.scheduledAt!)
        : '—';

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.bookingDeepLink(booking.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: oc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: oc.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: oc.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service?.title ?? 'Service',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$timeStr \u2014 ${booking.status.value}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: oc.secondaryText),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: oc.icons),
          ],
        ),
      ),
    );
  }
}

class _BlockedSlotTile extends StatelessWidget {
  const _BlockedSlotTile({required this.slot, required this.onDelete});
  final BlockedSlot slot;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final timeFmt = DateFormat('HH:mm', 'fr_FR');
    final label = slot.isFullDay
        ? 'Journ\u00e9e enti\u00e8re'
        : '${timeFmt.format(slot.date)} \u2013 ${timeFmt.format(slot.endDate!)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: oc.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oc.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: oc.error,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (slot.reason != null && slot.reason!.isNotEmpty)
                  Text(
                    slot.reason!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: oc.secondaryText),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline, size: 20, color: oc.error),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Block slot bottom sheet
// ---------------------------------------------------------------------------

class _BlockSlotSheet extends StatefulWidget {
  const _BlockSlotSheet({this.initialDate});
  final DateTime? initialDate;

  @override
  State<_BlockSlotSheet> createState() => _BlockSlotSheetState();
}

class _BlockSlotSheetState extends State<_BlockSlotSheet> {
  late DateTime _startDate;
  DateTime? _endDate; // null = single day
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _fullDay = true;
  bool _multiDay = false;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final dateFmt = DateFormat('EEE d MMM yyyy', 'fr_FR');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: oc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bloquer un cr\u00e9neau',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Start date
          Text('Date de d\u00e9but',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _pickStartDate,
            child: _DateRow(label: dateFmt.format(_startDate), oc: oc),
          ),
          const SizedBox(height: 12),

          // Multi-day toggle
          Row(
            children: [
              Expanded(
                child: Text('Plusieurs jours',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Switch(
                value: _multiDay,
                onChanged: (v) => setState(() {
                  _multiDay = v;
                  if (v) _endDate ??= _startDate;
                }),
                activeThumbColor: oc.primary,
              ),
            ],
          ),

          if (_multiDay) ...[
            Text('Date de fin',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _pickEndDate,
              child: _DateRow(
                label: _endDate != null
                    ? dateFmt.format(_endDate!)
                    : 'Choisir',
                oc: oc,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Full day toggle (only for single day)
          if (!_multiDay) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Journ\u00e9e enti\u00e8re',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Switch(
                  value: _fullDay,
                  onChanged: (v) => setState(() => _fullDay = v),
                  activeThumbColor: oc.primary,
                ),
              ],
            ),
            if (!_fullDay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: _startTime != null
                          ? '${_startTime!.hour.toString().padLeft(2, '0')}h${_startTime!.minute.toString().padLeft(2, '0')}'
                          : 'D\u00e9but',
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime:
                              _startTime ?? const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (t != null) setState(() => _startTime = t);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('\u2013',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Expanded(
                    child: _TimeButton(
                      label: _endTime != null
                          ? '${_endTime!.hour.toString().padLeft(2, '0')}h${_endTime!.minute.toString().padLeft(2, '0')}'
                          : 'Fin',
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime:
                              _endTime ?? const TimeOfDay(hour: 18, minute: 0),
                        );
                        if (t != null) setState(() => _endTime = t);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 12),

          // Reason
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Raison (optionnel)',
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Bloquer'),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _save() {
    DateTime startDt;
    DateTime? endDt;
    final reason = _reasonController.text.trim().isEmpty
        ? null
        : _reasonController.text.trim();

    if (_multiDay) {
      startDt = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final ed = _endDate ?? _startDate;
      endDt = DateTime(ed.year, ed.month, ed.day, 23, 59);
    } else if (_fullDay) {
      startDt = DateTime(_startDate.year, _startDate.month, _startDate.day);
    } else {
      final st = _startTime ?? const TimeOfDay(hour: 8, minute: 0);
      final et = _endTime ?? const TimeOfDay(hour: 18, minute: 0);
      startDt = DateTime(
          _startDate.year, _startDate.month, _startDate.day, st.hour, st.minute);
      endDt = DateTime(
          _startDate.year, _startDate.month, _startDate.day, et.hour, et.minute);
    }

    Navigator.of(context).pop(BlockedSlot(
      id: '',
      date: startDt,
      endDate: endDt,
      reason: reason,
    ));
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.oc});
  final String label;
  final dynamic oc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: oc.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oc.border),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: oc.primary),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: oc.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: oc.border),
        ),
        child: Center(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
