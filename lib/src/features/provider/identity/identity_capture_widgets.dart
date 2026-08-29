import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../application/identity/document_shutter.dart';

/// Shared pieces of the capture screens: the framing overlays, the instruction
/// banner (on its A7 scrim), and the two error states (permission, no camera).

/// A rounded rectangle framing hint for the ID card, drawn over the preview.
///
/// The frame is the main channel for people who do not read: its colour, the
/// ring that fills as the hold runs, and the icon above it say what to do
/// without a sentence. Meaning is never carried by colour alone (A3): every
/// state also has an icon, and the screen prints the matching text beside it.
class DocumentFrameOverlay extends StatelessWidget {
  const DocumentFrameOverlay({
    super.key,
    this.reason = DocumentShutterReason.noFrame,
    this.progress = 0,
    this.showFlipDemo = false,
  });

  final DocumentShutterReason reason;

  /// 0 to 1: how much of the hold has elapsed.
  final double progress;

  /// On the second side, show the card turning over while the shutter waits for
  /// a gesture. It is the only way someone who does not read learns that the
  /// card must be flipped rather than left where it is.
  final bool showFlipDemo;

  IconData get _icon => switch (reason) {
    DocumentShutterReason.noFrame => Icons.center_focus_weak,
    DocumentShutterReason.waitingForMotion => Icons.center_focus_weak,
    DocumentShutterReason.tooBlurred => Icons.blur_on,
    DocumentShutterReason.moving => Icons.pan_tool,
    DocumentShutterReason.steadying => Icons.pan_tool,
    DocumentShutterReason.ready => Icons.check_circle,
    DocumentShutterReason.refused => Icons.flip_camera_android,
  };

  Color get _color => switch (reason) {
    DocumentShutterReason.steadying => AppColors.accent,
    DocumentShutterReason.ready => AppColors.accent,
    DocumentShutterReason.refused => AppColors.warning,
    _ => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    // A Stack, not a Column: the frame sizes itself from the available width,
    // so stacking anything above it in a Column overflows on short surfaces.
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              // ID-1 card ratio (85.6 x 54 mm), the shape a national ID card
              // fills.
              aspectRatio: 85.6 / 54,
              child: FractionallySizedBox(
                widthFactor: 0.86,
                child: TweenAnimationBuilder<double>(
                  // Implicit and one-shot: the ring must never be a repeating
                  // animation, which would leave a frame permanently scheduled
                  // and hang every pumpAndSettle on this screen.
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 180),
                  builder: (context, value, _) => CustomPaint(
                    painter: _DocumentFramePainter(
                      color: _color,
                      progress: value,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The status icon sits above the frame, on its own scrim so it stays
          // legible over a bright scene (A1: an interface element carrying
          // meaning).
          Align(
            alignment: const Alignment(0, -0.78),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child:
                  showFlipDemo &&
                      reason == DocumentShutterReason.waitingForMotion
                  ? _FlipCardDemo(color: _color)
                  : Icon(_icon, color: _color, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card turning over, played a BOUNDED number of times.
///
/// Deliberately not a repeating animation: a `repeat()` keeps a frame scheduled
/// for ever, which would hang every `pumpAndSettle` on this screen (there are
/// seventeen of them across the capture tests). Three turns are enough to show
/// what is expected, then it rests.
class _FlipCardDemo extends StatelessWidget {
  const _FlipCardDemo({required this.color});

  final Color color;

  static const _turns = 3;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _turns.toDouble()),
      duration: const Duration(milliseconds: 1000 * _turns),
      builder: (context, t, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(math.sin(t * 2 * math.pi) * 1.1),
        child: child,
      ),
      child: Icon(Icons.badge_outlined, color: color, size: 32),
    );
  }
}

/// Draws the framing rectangle, and over it the portion of its outline that the
/// hold has already earned. A ring filling up is the anticipation signal for a
/// shot nobody asked for by pressing anything.
class _DocumentFramePainter extends CustomPainter {
  const _DocumentFramePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(AppSpacing.radiusLarge),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = progress > 0 ? color.withValues(alpha: 0.35) : color,
    );

    if (progress <= 0) return;

    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DocumentFramePainter old) =>
      old.progress != progress || old.color != color;
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
    this.hint,
  });

  final String step;
  final String instruction;

  /// Optional secondary line, e.g. "the photo is taken automatically". Null
  /// once it has nothing left to teach.
  final String? hint;

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
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                hint!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
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
