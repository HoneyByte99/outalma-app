import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';

class BookingDetailPage extends ConsumerWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return bookingAsync.when(
      loading: () => const _DetailLoading(),
      error: (_, __) => const _DetailError(),
      data: (booking) {
        if (booking == null) return const _DetailError();
        return _DetailContent(booking: booking);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync =
        ref.watch(serviceDetailProvider(booking.serviceId));
    final serviceTitle = serviceAsync.valueOrNull?.title ?? '---';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Détail de la réservation')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // ---- Service info ----
          _Section(
            title: 'Service',
            child: _InfoRow(
              icon: Icons.home_repair_service_outlined,
              label: serviceTitle,
            ),
          ),
          const SizedBox(height: 16),

          // ---- Request message ----
          _Section(
            title: 'Message',
            child: Text(
              booking.requestMessage.isNotEmpty
                  ? booking.requestMessage
                  : 'Aucun message',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Schedule ----
          if (booking.schedule != null) ...[
            _Section(
              title: 'Créneau',
              child: _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: booking.schedule!['description'] as String? ??
                    'Non précisé',
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---- Address ----
          if (booking.addressSnapshot != null) ...[
            _Section(
              title: 'Adresse',
              child: _InfoRow(
                icon: Icons.location_on_outlined,
                label: booking.addressSnapshot!['address'] as String? ??
                    'Non précisée',
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---- Status timeline ----
          _Section(
            title: 'Suivi',
            child: _StatusTimeline(booking: booking),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status timeline
// ---------------------------------------------------------------------------

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();

    return Column(
      children: events.asMap().entries.map((entry) {
        final isLast = entry.key == events.length - 1;
        final (label, date, isActive) = entry.value;
        return _TimelineRow(
          label: label,
          date: date,
          isActive: isActive,
          showLine: !isLast,
        );
      }).toList(),
    );
  }

  List<(String, DateTime?, bool)> _buildEvents() {
    return [
      ('Demande envoyée', booking.createdAt, true),
      if (booking.acceptedAt != null)
        ('Demande acceptée', booking.acceptedAt, true),
      if (booking.rejectedAt != null)
        ('Demande refusée', booking.rejectedAt, true),
      if (booking.startedAt != null)
        ('Service en cours', booking.startedAt, true),
      if (booking.cancelledAt != null)
        ('Annulée', booking.cancelledAt, true),
      if (booking.doneAt != null) ('Terminé', booking.doneAt, true),
      // Future milestone
      if (booking.status == BookingStatus.requested)
        ('En attente de réponse', null, false),
      if (booking.status == BookingStatus.accepted)
        ('Service à venir', null, false),
    ];
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.date,
    required this.isActive,
    required this.showLine,
  });

  final String label;
  final DateTime? date;
  final bool isActive;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.border;
    final dateLabel = date != null ? _formatDateTime(date!) : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Label + date
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isActive ? FontWeight.w500 : FontWeight.w400,
                          color: isActive
                              ? AppColors.primaryText
                              : AppColors.secondaryText,
                        ),
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section widget
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Date formatting helpers
// ---------------------------------------------------------------------------

String _formatDateTime(DateTime dt) {
  const months = [
    'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]}, $h:$m';
}

// ---------------------------------------------------------------------------
// Loading + error states
// ---------------------------------------------------------------------------

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réservation')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réservation')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.icons),
            const SizedBox(height: 16),
            Text(
              'Réservation introuvable',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}
