import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
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
    final bookingsAsync = ref.watch(providerBookingHistoryProvider);
    final blockedAsync = ref.watch(providerBlockedSlotsProvider);

    final bookings = bookingsAsync.valueOrNull ?? [];
    final blockedSlots = blockedAsync.valueOrNull ?? [];

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
      body: Column(
        children: [
          // Calendar
          TableCalendar<Object>(
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
          const Divider(height: 1),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _LegendDot(color: oc.primary, label: 'RDV'),
                const SizedBox(width: 16),
                _LegendDot(color: oc.error, label: 'Indisponible'),
              ],
            ),
          ),

          // Day detail
          Expanded(
            child: _selectedDay != null
                ? _DayDetail(
                    day: _selectedDay!,
                    bookings: bookings,
                    blockedSlots: blockedSlots,
                  )
                : Center(
                    child: Text(
                      'Sélectionnez un jour',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: oc.secondaryText),
                    ),
                  ),
          ),
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
    final result = await showModalBottomSheet<BlockedSlot>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BlockSlotSheet(initialDate: _selectedDay),
    );
    if (result != null && mounted) {
      final auth = ref.read(
        currentProviderProfileProvider,
      ).valueOrNull;
      if (auth != null) {
        await ref
            .read(providerRepositoryProvider)
            .addBlockedSlot(auth.uid, result);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Day detail — shows bookings + blocked slots for selected day
// ---------------------------------------------------------------------------

class _DayDetail extends ConsumerWidget {
  const _DayDetail({
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
      return Center(
        child: Text(
          'Aucun RDV ce jour',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: oc.secondaryText),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        for (final b in dayBookings)
          _BookingTile(booking: b),
        for (final s in daySlots)
          _BlockedSlotTile(slot: s, onDelete: () {
            final profile = ref.read(currentProviderProfileProvider).valueOrNull;
            if (profile != null) {
              ref.read(providerRepositoryProvider).removeBlockedSlot(
                    profile.uid,
                    s.id,
                  );
            }
          }),
      ],
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
          context.push(AppRoutes.providerBookingDetail(booking.id)),
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
  late DateTime _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _fullDay = true;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final dateFmt = DateFormat('EEE d MMMM yyyy', 'fr_FR');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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

          // Date
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('fr'),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: oc.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: oc.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: oc.primary),
                  const SizedBox(width: 10),
                  Text(dateFmt.format(_date),
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Full day toggle
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
                        initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
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
                        initialTime: _endTime ?? const TimeOfDay(hour: 18, minute: 0),
                      );
                      if (t != null) setState(() => _endTime = t);
                    },
                  ),
                ),
              ],
            ),
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
    );
  }

  void _save() {
    DateTime startDt;
    DateTime? endDt;

    if (_fullDay) {
      startDt = DateTime(_date.year, _date.month, _date.day);
    } else {
      final st = _startTime ?? const TimeOfDay(hour: 8, minute: 0);
      final et = _endTime ?? const TimeOfDay(hour: 18, minute: 0);
      startDt = DateTime(_date.year, _date.month, _date.day, st.hour, st.minute);
      endDt = DateTime(_date.year, _date.month, _date.day, et.hour, et.minute);
    }

    Navigator.of(context).pop(BlockedSlot(
      id: '', // Firestore will generate
      date: startDt,
      endDate: endDt,
      reason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
    ));
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
