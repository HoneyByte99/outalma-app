import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/provider/provider_providers.dart';
import '../../application/service/service_providers.dart';
import '../../domain/models/booking.dart';

class ProviderInboxPage extends ConsumerWidget {
  const ProviderInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(providerInboxProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Demandes reçues',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          inboxAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SliverFillRemaining(
              child: _ErrorState(),
            ),
            data: (bookings) => bookings.isEmpty
                ? SliverFillRemaining(child: _EmptyInbox())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _InboxCard(booking: bookings[i]),
                        childCount: bookings.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox card
// ---------------------------------------------------------------------------

class _InboxCard extends ConsumerWidget {
  const _InboxCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(booking.serviceId));
    final serviceTitle = serviceAsync.valueOrNull?.title ?? '---';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.providerBookingDetail(booking.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
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
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceTitle,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDate(booking.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.icons,
                  size: 20,
                ),
              ],
            ),
            if (booking.requestMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                booking.requestMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryText,
                      height: 1.4,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (booking.schedule != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    booking.schedule!['description'] as String? ??
                        'Créneau non précisé',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                  ),
                ],
              ),
            ],
          ],
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

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 56,
              color: AppColors.icons,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune demande en attente',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Les demandes des clients apparaîtront ici\ndès qu\'ils auront réservé un de vos services.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Impossible de charger les demandes.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryText,
            ),
      ),
    );
  }
}
