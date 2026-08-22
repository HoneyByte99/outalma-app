import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';

/// Shared pieces of the capture screens: the framing overlays, the instruction
/// banner (on its A7 scrim), and the two error states (permission, no camera).

/// A rounded rectangle framing hint for the ID card, drawn over the preview.
class DocumentFrameOverlay extends StatelessWidget {
  const DocumentFrameOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          // ID-1 card ratio (85.6 x 54 mm), the shape a national ID card fills.
          aspectRatio: 85.6 / 54,
          child: FractionallySizedBox(
            widthFactor: 0.86,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An oval framing hint for the selfie, drawn over the front preview.
class FaceFrameOverlay extends StatelessWidget {
  const FaceFrameOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.5,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step counter plus the current instruction, on a scrim of at least 60 percent
/// (A7). Meaning is never carried by colour alone (A3): it is plain text.
class CaptureInstructionBanner extends StatelessWidget {
  const CaptureInstructionBanner({
    super.key,
    required this.step,
    required this.instruction,
  });

  final String step;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.6),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera permission refused (AC-C11). When it can be reopened only from system
/// settings, the button routes there (iOS); otherwise it offers a plain retry.
class IdentityPermissionDeniedView extends StatelessWidget {
  const IdentityPermissionDeniedView({
    super.key,
    required this.canOpenSettings,
    this.onOpenSettings,
    this.onRetry,
  });

  final bool canOpenSettings;
  final Future<bool> Function()? onOpenSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _CenteredMessage(
      icon: Icons.no_photography_outlined,
      title: l10n.identityPermissionDeniedTitle,
      body: l10n.identityPermissionDeniedBody,
      actionLabel: canOpenSettings
          ? l10n.identityOpenSettings
          : l10n.identityRetry,
      onAction: canOpenSettings ? () => onOpenSettings?.call() : onRetry,
    );
  }
}

/// No usable camera on the device (AC-C11 sibling: unavailable, not denied).
class IdentityCameraUnavailableView extends StatelessWidget {
  const IdentityCameraUnavailableView({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _CenteredMessage(
      icon: Icons.videocam_off_outlined,
      title: l10n.identityCameraUnavailableTitle,
      body: l10n.identityCameraUnavailableBody,
      actionLabel: onRetry != null ? l10n.identityRetry : null,
      onAction: onRetry,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 48),
            const SizedBox(height: AppSpacing.l),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
