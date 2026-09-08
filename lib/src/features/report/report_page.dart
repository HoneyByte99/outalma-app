import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/report/report_providers.dart';
import '../../../l10n/app_localizations.dart';

/// Report page.
///
/// [targetType] is "user", "service", or "message".
/// [targetId] is the id of the entity being reported.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  String? _selectedReason;
  bool _submitting = false;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _submitting) return;

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    setState(() => _submitting = true);
    try {
      final detailsRaw = _detailsController.text.trim();
      await ref
          .read(createReportUseCaseProvider)
          .call(
            reporterId: authState.user.id,
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _selectedReason!,
            details: detailsRaw.isEmpty ? null : detailsRaw,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.reportSuccess)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reportError),
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

    final reasons = [
      l10n.reportReason1,
      l10n.reportReason2,
      l10n.reportReason3,
      l10n.reportReason4,
      l10n.reportReason5,
      l10n.reportReason6,
    ];

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.reportTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
      ),
      // The footer is part of the body, which the Scaffold shrinks with the
      // keyboard: the submit button stays visible while typing. A
      // bottomNavigationBar would NOT (the Scaffold pins it to the screen
      // bottom, behind the keyboard), and the previous non-scrollable column
      // overflowed by ~86 px on a 375x667 phone once the keyboard was up.
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.reportQuestion,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.reportSubtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                  ),
                  const SizedBox(height: 28),

                  // Reason chips
                  for (var i = 0; i < reasons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ReasonTile(
                      reason: reasons[i],
                      selected: _selectedReason == reasons[i],
                      onTap: () => setState(() => _selectedReason = reasons[i]),
                    ),
                  ],

                  // Optional details, only shown once a reason is selected to
                  // avoid cluttering the screen during the initial choice.
                  if (_selectedReason != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.reportDetailsLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _detailsController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: l10n.reportDetailsHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedReason == null || _submitting)
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: oc.error),
                child: _submitting
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: oc.cardSurface,
                        ),
                      )
                    : Text(l10n.reportSubmit),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final String reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? oc.primary.withValues(alpha: 0.06) : oc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? oc.primary : oc.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? oc.primary : oc.primaryText,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: oc.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
