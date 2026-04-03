import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_actions.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/phone_share/phone_share_providers.dart';
import '../../application/review/review_providers.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/booking.dart';

String _formatSchedule(DateTime dt) {
  final dateFmt = DateFormat('EEE d MMMM yyyy', 'fr_FR');
  final timeFmt = DateFormat('HH:mm', 'fr_FR');
  return '${dateFmt.format(dt)} \u00e0 ${timeFmt.format(dt)}';
}

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
    final oc = context.oc;
    final serviceAsync =
        ref.watch(serviceDetailProvider(booking.serviceId));
    final serviceTitle = serviceAsync.valueOrNull?.title ?? '---';

    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final uid = authState is AuthAuthenticated ? authState.user.id : null;

    // Bottom bar logic — mutually exclusive based on role + status.
    Widget? bottomBar;
    if (uid == booking.providerId) {
      if (booking.status == BookingStatus.requested) {
        bottomBar = _ProviderActionBar(booking: booking);
      } else if (booking.status == BookingStatus.accepted) {
        bottomBar = _MarkInProgressBar(booking: booking);
      }
    } else if (uid == booking.customerId) {
      if (booking.status == BookingStatus.inProgress) {
        bottomBar = _ConfirmDoneBar(booking: booking);
      }
    }

    // The "other" participant we can report
    final otherUid = uid == booking.customerId
        ? booking.providerId
        : booking.customerId;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: const Text('Détail de la réservation'),
        actions: [
          if (otherUid.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 20),
              tooltip: 'Signaler',
              onPressed: () => context.push(
                AppRoutes.report(type: 'user', id: otherUid),
              ),
            ),
        ],
      ),
      bottomNavigationBar: bottomBar,
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
                    color: oc.secondaryText,
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Schedule ----
          if (booking.scheduledAt != null) ...[
            _Section(
              title: 'Créneau',
              child: _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: _formatSchedule(booking.scheduledAt!),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (booking.schedule != null) ...[
            _Section(
              title: 'Créneau',
              child: _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: booking.schedule!['description'] as String? ??
                    'Non pr\u00e9cis\u00e9',
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

          // ---- Contact unlock ----
          if (booking.status == BookingStatus.accepted ||
              booking.status == BookingStatus.inProgress ||
              booking.status == BookingStatus.done) ...[
            _ContactSection(
              bookingId: booking.id,
              otherParticipantId: uid == booking.customerId
                  ? booking.providerId
                  : booking.customerId,
              currentUid: uid,
            ),
            const SizedBox(height: 16),
          ],

          // ---- Chat CTA (when chat is unlocked) ----
          if (booking.chatId != null &&
              (booking.status == BookingStatus.accepted ||
                  booking.status == BookingStatus.inProgress ||
                  booking.status == BookingStatus.done)) ...[
            _ChatButton(chatId: booking.chatId!),
            const SizedBox(height: 16),
          ],

          // ---- Review CTA (when done and not yet reviewed) ----
          if (booking.status == BookingStatus.done) ...[
            _ReviewSection(
              bookingId: booking.id,
              currentUid: uid,
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
// Contact unlock section
// ---------------------------------------------------------------------------

class _ContactSection extends ConsumerWidget {
  const _ContactSection({
    required this.bookingId,
    required this.otherParticipantId,
    required this.currentUid,
  });

  final String bookingId;
  final String otherParticipantId;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final sharesAsync = ref.watch(phoneSharesProvider(bookingId));
    final hasSharedAsync = ref.watch(hasSharedPhoneProvider(bookingId));

    // Current user's phone from auth state
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final myPhone = authState is AuthAuthenticated
        ? authState.user.phoneE164
        : null;

    return sharesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (shares) {
        final otherShare =
            shares.where((s) => s.uid == otherParticipantId).firstOrNull;
        final hasShared = hasSharedAsync.valueOrNull ?? false;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: oc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: oc.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: oc.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),

              // Other participant's phone
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: oc.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: oc.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    otherShare?.phone ?? 'Numéro non encore partagé',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: otherShare != null
                              ? oc.primaryText
                              : oc.secondaryText,
                          fontWeight: otherShare != null
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                  ),
                ],
              ),

              // Share own phone CTA
              if (!hasShared && myPhone != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _SharePhoneButton(
                  bookingId: bookingId,
                  uid: currentUid!,
                  phone: myPhone,
                ),
              ] else if (!hasShared && myPhone == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ajoutez votre numéro dans votre profil pour le partager.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: oc.secondaryText,
                      ),
                ),
              ],

              if (hasShared) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: oc.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Votre numéro est partagé',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: oc.success,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SharePhoneButton extends ConsumerStatefulWidget {
  const _SharePhoneButton({
    required this.bookingId,
    required this.uid,
    required this.phone,
  });

  final String bookingId;
  final String uid;
  final String phone;

  @override
  ConsumerState<_SharePhoneButton> createState() => _SharePhoneButtonState();
}

class _SharePhoneButtonState extends ConsumerState<_SharePhoneButton> {
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await ref.read(phoneShareRepositoryProvider).share(
            bookingId: widget.bookingId,
            uid: widget.uid,
            phone: widget.phone,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de partager le numéro.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _sharing ? null : _share,
        icon: _sharing
            ? SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: oc.primary,
                ),
              )
            : const Icon(Icons.phone_outlined, size: 16),
        label: Text('Partager mon numéro (${widget.phone})'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat CTA
// ---------------------------------------------------------------------------

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => context.push(AppRoutes.chat(chatId)),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: const Text('Accéder au chat'),
    );
  }
}

// ---------------------------------------------------------------------------
// Review section — shows form button if not yet reviewed, else confirmation
// ---------------------------------------------------------------------------

class _ReviewSection extends ConsumerWidget {
  const _ReviewSection({
    required this.bookingId,
    required this.currentUid,
  });

  final String bookingId;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final hasReviewedAsync = ref.watch(hasReviewedProvider(bookingId));

    return hasReviewedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hasReviewed) {
        if (hasReviewed) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: oc.successAccent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: oc.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: oc.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Avis envoyé — merci !',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: oc.success,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          );
        }

        return OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.review(bookingId)),
          icon: const Icon(Icons.star_outline_rounded, size: 18),
          label: const Text('Laisser un avis'),
        );
      },
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
    final oc = context.oc;
    final color = isActive ? oc.primary : oc.border;
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
                      color: oc.border,
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
                              ? oc.primaryText
                              : oc.secondaryText,
                        ),
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: oc.secondaryText,
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
    final oc = context.oc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: oc.secondaryText,
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
        Icon(icon, size: 18, color: context.oc.secondaryText),
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
// Provider accept / reject bottom bar
// ---------------------------------------------------------------------------

class _ProviderActionBar extends ConsumerStatefulWidget {
  const _ProviderActionBar({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_ProviderActionBar> createState() => _ProviderActionBarState();
}

class _ProviderActionBarState extends ConsumerState<_ProviderActionBar> {
  bool _loadingAccept = false;
  bool _loadingReject = false;

  Future<void> _accept() async {
    setState(() => _loadingAccept = true);
    try {
      await ref.read(acceptBookingUseCaseProvider).call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande acceptée')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Erreur lors de l\'acceptation.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de l\'acceptation.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAccept = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loadingReject = true);
    try {
      await ref.read(rejectBookingUseCaseProvider).call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande refusée')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Erreur lors du refus.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du refus.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingReject = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final busy = _loadingAccept || _loadingReject;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: oc.surface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: oc.error,
                side: BorderSide(color: oc.error),
              ),
              child: _loadingReject
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: oc.error,
                      ),
                    )
                  : const Text('Refuser'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: busy ? null : _accept,
              child: _loadingAccept
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: oc.surface,
                      ),
                    )
                  : const Text('Accepter'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider: mark in progress bar
// ---------------------------------------------------------------------------

class _MarkInProgressBar extends ConsumerStatefulWidget {
  const _MarkInProgressBar({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_MarkInProgressBar> createState() =>
      _MarkInProgressBarState();
}

class _MarkInProgressBarState extends ConsumerState<_MarkInProgressBar> {
  bool _loading = false;

  Future<void> _markInProgress() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(markInProgressUseCaseProvider)
          .call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service démarré')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Erreur.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du démarrage.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
        onPressed: _loading ? null : _markInProgress,
        child: _loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: oc.surface,
                ),
              )
            : const Text('Démarrer le service'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client: confirm done bar
// ---------------------------------------------------------------------------

class _ConfirmDoneBar extends ConsumerStatefulWidget {
  const _ConfirmDoneBar({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_ConfirmDoneBar> createState() => _ConfirmDoneBarState();
}

class _ConfirmDoneBarState extends ConsumerState<_ConfirmDoneBar> {
  bool _loading = false;

  Future<void> _confirmDone() async {
    // Ask for confirmation before marking as done.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la fin ?'),
        content: const Text(
          'En confirmant, le service sera marqué comme terminé. '
          'Vous pourrez ensuite laisser un avis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(confirmDoneUseCaseProvider).call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service terminé !')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Erreur.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la confirmation.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
        onPressed: _loading ? null : _confirmDone,
        style: ElevatedButton.styleFrom(
          backgroundColor: oc.success,
        ),
        child: _loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: oc.surface,
                ),
              )
            : const Text('Confirmer la fin du service'),
      ),
    );
  }
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
            Icon(Icons.error_outline, size: 56, color: context.oc.icons),
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
