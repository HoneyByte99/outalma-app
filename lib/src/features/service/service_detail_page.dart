import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/models/service.dart';
import '../booking/booking_request_sheet.dart';

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return serviceAsync.when(
      loading: () => const _ServiceDetailLoading(),
      error: (_, __) => const _ServiceDetailError(),
      data: (service) {
        if (service == null) {
          return const _ServiceDetailError();
        }
        return _ServiceDetailContent(service: service);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

class _ServiceDetailContent extends ConsumerWidget {
  const _ServiceDetailContent({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final priceLabel = service.priceType == PriceType.hourly
        ? '${(service.price / 100).toStringAsFixed(0)} €/h'
        : '${(service.price / 100).toStringAsFixed(0)} € (forfait)';

    return Scaffold(
      backgroundColor: oc.background,
      body: CustomScrollView(
        slivers: [
          // ---- Collapsible hero header ----
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: oc.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: oc.surface.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: oc.primaryText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: oc.border,
                child: Center(
                  child: Image.asset(
                    'assets/images/logo_outalma.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // ---- Body ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  _CategoryBadge(categoryId: service.categoryId),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    service.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Text(
                    priceLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: oc.primary,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Provider info
                  _ProviderRow(providerId: service.providerId),
                  const SizedBox(height: 20),

                  // Description
                  if (service.description != null &&
                      service.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _ExpandableText(text: service.description!),
                    const SizedBox(height: 20),
                  ],

                  // Service area
                  if (service.serviceArea != null &&
                      service.serviceArea!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: oc.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.serviceArea!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: oc.secondaryText),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ---- Sticky bottom bar ----
      bottomNavigationBar: _BookingBottomBar(service: service),
    );
  }
}

// ---------------------------------------------------------------------------
// Category badge
// ---------------------------------------------------------------------------

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.categoryId});

  final CategoryId categoryId;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: oc.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(categoryId),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: oc.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _label(CategoryId id) {
    switch (id) {
      case CategoryId.menage:
        return 'Ménage';
      case CategoryId.plomberie:
        return 'Plomberie';
      case CategoryId.jardinage:
        return 'Jardinage';
      case CategoryId.autre:
        return 'Autre';
    }
  }
}

// ---------------------------------------------------------------------------
// Provider row — loads display name from auth user state if it's the same UID,
// otherwise falls back to a placeholder.
// ---------------------------------------------------------------------------

class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    // For MVP we show a minimal provider row without a separate provider name
    // lookup — a full provider profile page is Phase 4.
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: oc.border,
          child: Icon(Icons.person_outline, color: oc.icons),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prestataire',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: oc.secondaryText,
                    ),
              ),
              Text(
                'Voir le profil',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: oc.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable description text
// ---------------------------------------------------------------------------

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  static const _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : _maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: oc.secondaryText,
                height: 1.5,
              ),
        ),
        if (widget.text.length > 200) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Voir moins' : 'Voir plus',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky booking bottom bar
// ---------------------------------------------------------------------------

class _BookingBottomBar extends StatelessWidget {
  const _BookingBottomBar({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: oc.surface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: ElevatedButton(
        onPressed: () => _openBookingSheet(context),
        child: const Text('Demander ce service'),
      ),
    );
  }

  void _openBookingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingRequestSheet(
        serviceId: service.id,
        providerId: service.providerId,
        serviceTitle: service.title,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading state
// ---------------------------------------------------------------------------

class _ServiceDetailLoading extends StatelessWidget {
  const _ServiceDetailLoading();

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      body: Column(
        children: [
          Container(height: 240, color: oc.border),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: 80, color: oc.border),
                const SizedBox(height: 12),
                Container(height: 24, width: 200, color: oc.border),
                const SizedBox(height: 8),
                Container(height: 20, width: 100, color: oc.border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ServiceDetailError extends StatelessWidget {
  const _ServiceDetailError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.oc.background,
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: context.oc.icons),
            const SizedBox(height: 16),
            Text(
              'Service introuvable',
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
