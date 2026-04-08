import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
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

String _formatSchedule(DateTime dt, String locale) {
  final dateFmt = DateFormat('EEE d MMMM yyyy', locale);
  final timeFmt = DateFormat('HH:mm', locale);
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final locale = Localizations.localeOf(context).toString();
    final serviceAsync = ref.watch(serviceDetailProvider(booking.serviceId));
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
      if (booking.status == BookingStatus.requested) {
        bottomBar = _CancelBookingBar(booking: booking);
      } else if (booking.status == BookingStatus.inProgress) {
        bottomBar = _ConfirmDoneBar(booking: booking);
      }
    }

    // The "other" participant we can report
    final otherUid =
        uid == booking.customerId ? booking.providerId : booking.customerId;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.bookingDetailTitle),
        actions: [
          if (otherUid.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 20),
              tooltip: l10n.bookingReport,
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
            title: l10n.bookingService,
            child: _InfoRow(
              icon: Icons.home_repair_service_outlined,
              label: serviceTitle,
            ),
          ),
          const SizedBox(height: 16),

          // ---- Request message ----
          _Section(
            title: l10n.bookingMessage,
            child: Text(
              booking.requestMessage.isNotEmpty
                  ? booking.requestMessage
                  : l10n.bookingNoMessage,
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
              title: l10n.bookingSchedule,
              child: _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: _formatSchedule(booking.scheduledAt!, locale),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (booking.schedule != null) ...[
            _Section(
              title: l10n.bookingSchedule,
              child: _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: booking.schedule!['description'] as String? ??
                    l10n.bookingScheduleUnspecified,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---- Address ----
          if (booking.addressSnapshot != null) ...[
            _Section(
              title: l10n.bookingAddress,
              child: _InfoRow(
                icon: Icons.location_on_outlined,
                label: booking.addressSnapshot!['address'] as String? ??
                    l10n.bookingAddressUnspecified,
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
            title: l10n.bookingTimeline,
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final sharesAsync = ref.watch(phoneSharesProvider(bookingId));
    final hasSharedAsync = ref.watch(hasSharedPhoneProvider(bookingId));

    // Current user's phone from auth state
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final myPhone =
        authState is AuthAuthenticated ? authState.user.phoneE164 : null;

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
                l10n.bookingContact,
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
                    otherShare?.phone ?? l10n.bookingPhoneNotShared,
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
                  l10n.bookingAddPhoneInProfile,
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
                      l10n.bookingPhoneShared,
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
    final errMsg = AppLocalizations.of(context)!.bookingSharePhoneError;
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
            content: Text(errMsg),
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
    final l10n = AppLocalizations.of(context)!;
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
        label: Text(l10n.bookingSharePhone(widget.phone)),
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
    final l10n = AppLocalizations.of(context)!;
    return ElevatedButton.icon(
      onPressed: () => context.push(AppRoutes.chat(chatId)),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(l10n.bookingOpenChat),
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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.bookingReviewSent,
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
          label: Text(l10n.bookingLeaveReview),
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
    final l10n = AppLocalizations.of(context)!;
    final events = _buildEvents(l10n);

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

  List<(String, DateTime?, bool)> _buildEvents(AppLocalizations l10n) {
    return [
      (l10n.timelineRequestSent, booking.createdAt, true),
      if (booking.acceptedAt != null)
        (l10n.timelineAccepted, booking.acceptedAt, true),
      if (booking.rejectedAt != null)
        (l10n.timelineRejected, booking.rejectedAt, true),
      if (booking.startedAt != null)
        (l10n.timelineInProgress, booking.startedAt, true),
      if (booking.cancelledAt != null)
        (l10n.timelineCancelled, booking.cancelledAt, true),
      if (booking.doneAt != null) (l10n.timelineDone, booking.doneAt, true),
      // Future milestone
      if (booking.status == BookingStatus.requested)
        (l10n.timelinePendingResponse, null, false),
      if (booking.status == BookingStatus.accepted)
        (l10n.timelineUpcoming, null, false),
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
                          color:
                              isActive ? oc.primaryText : oc.secondaryText,
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
    final acceptedMsg = AppLocalizations.of(context)!.bookingAccepted;
    final acceptErrMsg = AppLocalizations.of(context)!.bookingAcceptError;
    setState(() => _loadingAccept = true);
    try {
      await ref.read(acceptBookingUseCaseProvider).call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(acceptedMsg)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? acceptErrMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(acceptErrMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAccept = false);
    }
  }

  Future<void> _reject() async {
    final rejectedMsg = AppLocalizations.of(context)!.bookingRejected;
    final rejectErrMsg = AppLocalizations.of(context)!.bookingRejectError;
    setState(() => _loadingReject = true);
    try {
      await ref.read(rejectBookingUseCaseProvider).call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rejectedMsg)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? rejectErrMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rejectErrMsg),
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
    final l10n = AppLocalizations.of(context)!;
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
                  : Text(l10n.bookingReject),
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
                  : Text(l10n.bookingAccept),
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
    final startedMsg = AppLocalizations.of(context)!.bookingServiceStarted;
    final startErrMsg = AppLocalizations.of(context)!.bookingStartError;
    setState(() => _loading = true);
    try {
      await ref.read(markInProgressUseCaseProvider).call(widget.booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(startedMsg)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? startErrMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(startErrMsg),
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
    final l10n = AppLocalizations.of(context)!;
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
            : Text(l10n.bookingStartService),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client: cancel booking bar (status == requested)
// ---------------------------------------------------------------------------

class _CancelBookingBar extends ConsumerStatefulWidget {
  const _CancelBookingBar({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_CancelBookingBar> createState() => _CancelBookingBarState();
}

class _CancelBookingBarState extends ConsumerState<_CancelBookingBar> {
  bool _loading = false;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final cancelTitle = l10n.bookingCancelTitle;
    final cancelContent = l10n.bookingCancelContent;
    final cancelNo = l10n.bookingCancelNo;
    final cancelYes = l10n.bookingCancelYes;
    final cancelErr = l10n.bookingCancelError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cancelTitle),
        content: Text(cancelContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelNo),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.oc.error,
              minimumSize: Size.zero,
            ),
            child: Text(cancelYes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref.read(cancelBookingUseCaseProvider).call(widget.booking.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cancelErr),
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: OutlinedButton(
          onPressed: _loading ? null : _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: oc.error,
            side: BorderSide(color: oc.error),
          ),
          child: _loading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: oc.error,
                  ),
                )
              : Text(l10n.bookingCancelButton),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final doneTitle = l10n.bookingConfirmDoneTitle;
    final doneContent = l10n.bookingConfirmDoneContent;
    final confirmLabel = l10n.confirm;
    final cancelLabel = l10n.cancel;
    final doneSuccess = l10n.bookingDoneSuccess;
    final doneErr = l10n.bookingDoneError;

    // Ask for confirmation before marking as done.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doneTitle),
        content: Text(doneContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
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
          SnackBar(content: Text(doneSuccess)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? doneErr),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(doneErr),
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
    final l10n = AppLocalizations.of(context)!;
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
            : Text(l10n.bookingConfirmDoneButton),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: context.oc.icons),
            const SizedBox(height: 16),
            Text(
              l10n.bookingNotFound,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.back),
            ),
          ],
        ),
      ),
    );
  }
}
