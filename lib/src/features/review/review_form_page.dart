import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/review/review_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/enums/reviewer_role.dart';
import '../../../l10n/app_localizations.dart';

/// Full-screen form to leave a bilateral review after a booking is done.
///
/// The page resolves the booking to determine reviewer/reviewee ids and role.
class ReviewFormPage extends ConsumerWidget {
  const ReviewFormPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return bookingAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.reviewBookingNotFound)),
      ),
      data: (booking) {
        if (booking == null || booking.status != BookingStatus.done) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(l10n.reviewOnlyAfterDone),
            ),
          );
        }

        final authState = ref.read(authNotifierProvider).valueOrNull;
        if (authState is! AuthAuthenticated) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final uid = authState.user.id;
        final isClient = uid == booking.customerId;
        final reviewerId = uid;
        final revieweeId = isClient ? booking.providerId : booking.customerId;
        final role =
            isClient ? ReviewerRole.client : ReviewerRole.provider;

        return _ReviewForm(
          bookingId: bookingId,
          reviewerId: reviewerId,
          revieweeId: revieweeId,
          reviewerRole: role,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Form widget
// ---------------------------------------------------------------------------

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.reviewerRole,
  });

  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final ReviewerRole reviewerRole;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(createReviewUseCaseProvider).call(
            bookingId: widget.bookingId,
            reviewerId: widget.reviewerId,
            revieweeId: widget.revieweeId,
            reviewerRole: widget.reviewerRole,
            rating: _rating,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reviewError),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final headingLabel = widget.reviewerRole == ReviewerRole.client
        ? l10n.reviewEvaluateProvider
        : l10n.reviewEvaluateClient;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.reviewTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text(
              headingLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reviewHelp,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: oc.secondaryText),
            ),
            const SizedBox(height: 32),

            // Star rating
            Text(
              l10n.reviewRating,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: oc.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _StarRating(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
            const SizedBox(height: 28),

            // Comment
            Text(
              l10n.reviewComment,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: oc.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.reviewCommentHint,
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: oc.surface,
                      ),
                    )
                  : Text(l10n.reviewSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Star rating widget
// ---------------------------------------------------------------------------

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 40,
              color: filled ? oc.warning : oc.border,
            ),
          ),
        );
      }),
    );
  }
}
