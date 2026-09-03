import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../app/router.dart';
import '../../../application/identity/identity_verification_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/enums/identity_status.dart';
import '../../../domain/identity/identity_status_view.dart';
import '../../../domain/models/identity_verification_record.dart';

/// The follow-up screen: reads the provider's own file (archi 5.6) and renders
/// one distinct state per situation (AC-C16). It is also the entry surface the
/// dashboard hub line opens, so a provider with no file lands on "not verified"
/// with the path to start.
///
/// The state read is the private file, not the public projection: the file
/// carries the reviewer's reason and the attempt rank, which the projection
/// never holds (archi 5.6). The badge itself is still driven by the projection
/// elsewhere (IdentityTrustSignal); this screen shows the story.
class IdentityStatusPage extends ConsumerWidget {
  const IdentityStatusPage({super.key, required this.onStartVerification});

  /// Opens the capture entry (the guide on mobile, the explainer on web). Used
  /// by both the "verify" and the "restart" actions.
  final VoidCallback onStartVerification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(myIdentityVerificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.identityStatusTitle),
        // Explicit, not automatic: this screen is reached both by push() (a
        // poppable stack, e.g. from the dashboard hub line) and by go() or a
        // cold-start deep link (no stack at all, e.g. after finishing capture
        // or opening a notification). automaticallyImplyLeading only covers
        // the first case, which is exactly how a provider could submit their
        // ID and land on "verification pending" with no way out but killing
        // the app. Falls back to the provider dashboard, the mode this screen
        // lives in, when there is nothing to pop to.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go(AppRoutes.providerHome);
            }
          },
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ReadError(
            onRetry: () => ref.invalidate(myIdentityVerificationProvider),
          ),
          data: (record) => _StatusBody(
            record: record,
            onStartVerification: onStartVerification,
          ),
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.record, required this.onStartVerification});

  final IdentityVerificationRecord? record;
  final VoidCallback onStartVerification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final textTheme = Theme.of(context).textTheme;

    // A null record is the absence of any file: "not verified".
    final status = record?.status ?? IdentityStatus.none;
    final view = identityStatusViewOf(
      status,
      attempt: record?.attempt ?? 1,
      priority: record?.priority ?? false,
    );

    final IconData icon;
    final Color accent;
    final String title;
    final String body;
    String? actionLabel;

    switch (view) {
      case IdentityStatusView.notVerified:
        icon = Icons.shield_outlined;
        accent = oc.secondaryText;
        title = l10n.trustUnverifiedLabel;
        body = l10n.identityStatusNoneBody;
        actionLabel = l10n.identityStatusStartCta;
      case IdentityStatusView.pending:
        icon = Icons.schedule_rounded;
        accent = oc.trustPendingText;
        title = l10n.trustPendingLabel;
        body = record?.submittedAt != null
            ? l10n.identityStatusPendingBody(
                formatAbsoluteDate(record!.submittedAt!.toLocal()),
              )
            : l10n.identityStatusPendingBodyNoDate;
      case IdentityStatusView.verified:
        icon = Icons.verified_rounded;
        accent = oc.trustVerifiedText;
        title = l10n.trustVerifiedLabel;
        body = record?.reviewedAt != null
            ? l10n.identityStatusVerifiedBody(
                formatAbsoluteDate(record!.reviewedAt!.toLocal()),
              )
            : l10n.identityStatusVerifiedBodyNoDate;
      case IdentityStatusView.rejected:
        icon = Icons.error_outline;
        accent = oc.trustRejectedText;
        title = l10n.identityStatusRejectedTitle;
        body = _reason(l10n, record);
        actionLabel = l10n.identityStatusRestartCta;
      case IdentityStatusView.rejectedPriority:
        icon = Icons.error_outline;
        accent = oc.trustRejectedText;
        title = l10n.identityStatusRejectedTitle;
        body = '${_reason(l10n, record)}\n\n${l10n.identityStatusPriorityNote}';
        actionLabel = l10n.identityStatusRestartCta;
      case IdentityStatusView.revoked:
        icon = Icons.error_outline;
        accent = oc.trustRejectedText;
        title = l10n.identityStatusRevokedTitle;
        body = _reason(l10n, record);
        actionLabel = l10n.identityStatusRestartCta;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: oc.cardSurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(color: oc.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accent),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  body,
                  style: textTheme.bodyMedium?.copyWith(color: oc.primaryText),
                ),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: onStartVerification,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  // The reviewer's reason is shown verbatim (AC-C17). A missing reason falls to
  // a neutral line so the card never renders an empty body.
  String _reason(AppLocalizations l10n, IdentityVerificationRecord? record) {
    final reason = record?.rejectionReason;
    if (reason == null || reason.trim().isEmpty) {
      return l10n.identityStatusNoReason;
    }
    return reason;
  }
}

class _ReadError extends StatelessWidget {
  const _ReadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: oc.secondaryText),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.identityStatusUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.l),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.identityRetry)),
          ],
        ),
      ),
    );
  }
}
