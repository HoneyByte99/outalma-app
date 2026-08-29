import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../domain/identity/liveness_challenge.dart';

/// A face that demonstrates the liveness gesture instead of describing it.
///
/// The selfie step asks the user to turn their head and come back to the lens.
/// Until now it only said so in French, which is useless to the providers this
/// increment exists for. A drawn face performing the movement carries the same
/// instruction without a word.
///
/// The demonstration turns LEFT, but the challenge itself reads only the
/// magnitude of the yaw: mirroring it and turning right passes just as well.
/// Nobody fails for copying the animation the wrong way round.
///
/// The animation is INFORMATIVE, not decorative, so it keeps running under the
/// system's reduce-motion preference (A8) and the banner keeps the equivalent
/// sentence beside it. It is white on a 60 percent scrim, an interface element
/// carrying meaning, so the line that applies is A1 at 3:1.
///
/// TO VERIFY ON DEVICE: the perceived direction. The front preview is mirrored
/// differently per platform, so the demonstration may read as the opposite of
/// what the user sees of themselves. The challenge does not depend on it.
class LivenessFaceGuide extends StatefulWidget {
  const LivenessFaceGuide({super.key, required this.state, this.size = 120});

  final LivenessState state;
  final double size;

  @override
  State<LivenessFaceGuide> createState() => _LivenessFaceGuideState();
}

class _LivenessFaceGuideState extends State<LivenessFaceGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// How far the demonstration turns, in radians. Comfortably past the 25
  /// degree threshold the challenge asks for, so copying it succeeds.
  static const _maxYaw = 0.61;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncToState();
  }

  @override
  void didUpdateWidget(LivenessFaceGuide old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncToState();
  }

  /// Only `turnHead` loops. Every other state is still, which is what keeps the
  /// pumpAndSettle calls across the capture tests able to converge: a
  /// permanently repeating animation would keep a frame scheduled for ever.
  void _syncToState() {
    switch (widget.state) {
      case LivenessState.turnHead:
        _controller.repeat(reverse: true);
      case LivenessState.returnToFront:
        // Play the way back once, then rest facing the lens.
        _controller.reverse(
          from: _controller.value == 0 ? 1 : _controller.value,
        );
      case LivenessState.waitingFace:
      case LivenessState.multipleFaces:
      case LivenessState.ready:
      case LivenessState.expired:
        _controller
          ..stop()
          ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n) => l10n.identityLivenessFaceGuideLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: _label(l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          // A7's scrim, which also gives the white strokes their contrast (A1).
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A directional arrow, visible only while a turn is being asked
            // for. Meaning never rides on the animation alone (A3).
            AnimatedOpacity(
              opacity: widget.state == LivenessState.turnHead ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            AnimatedBuilder(
              // Scoped to the guide: the camera preview beside it must never
              // rebuild at animation rate (P5).
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: Size.square(widget.size),
                painter: _FacePainter(
                  yaw: -_maxYaw * _controller.value,
                  state: widget.state,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a face seen from the front, foreshortened as it turns.
///
/// The turn is faked rather than projected: the head narrows and the features
/// slide with it, which reads as a head turning far better than rotating a flat
/// picture would.
class _FacePainter extends CustomPainter {
  const _FacePainter({required this.yaw, required this.state});

  /// Radians. Negative turns to the viewer's left.
  final double yaw;
  final LivenessState state;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    final centre = Offset(size.width / 2, size.height / 2);
    final headWidth = size.width * 0.34 * math.cos(yaw).abs().clamp(0.45, 1.0);
    final headHeight = size.height * 0.40;
    // Features drift towards the direction of the turn.
    final drift = size.width * 0.16 * math.sin(yaw);

    canvas.drawOval(
      Rect.fromCenter(
        center: centre,
        width: headWidth * 2,
        height: headHeight * 2,
      ),
      stroke,
    );

    if (state == LivenessState.multipleFaces) {
      // A second head, struck through: only one face may be in frame.
      canvas.drawOval(
        Rect.fromCenter(
          center: centre.translate(size.width * 0.26, 0),
          width: headWidth * 1.2,
          height: headHeight * 1.2,
        ),
        stroke,
      );
      canvas.drawLine(
        centre.translate(size.width * 0.10, -size.height * 0.28),
        centre.translate(size.width * 0.42, size.height * 0.28),
        stroke..color = AppColors.warning,
      );
      return;
    }

    final eyeY = centre.dy - headHeight * 0.25;
    // The far eye recedes as the head turns away.
    final farEye = (1 - yaw.abs() / 0.9).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(centre.dx + drift - headWidth * 0.42, eyeY),
      3,
      Paint()..color = Colors.white.withValues(alpha: farEye),
    );
    canvas.drawCircle(
      Offset(centre.dx + drift + headWidth * 0.42, eyeY),
      3,
      Paint()..color = Colors.white,
    );

    // Nose, then mouth.
    canvas.drawLine(
      Offset(centre.dx + drift, centre.dy - headHeight * 0.05),
      Offset(
        centre.dx + drift + headWidth * 0.14,
        centre.dy + headHeight * 0.2,
      ),
      stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centre.dx + drift, centre.dy + headHeight * 0.42),
        width: headWidth * 0.9,
        height: headHeight * 0.35,
      ),
      0.2,
      math.pi - 0.4,
      false,
      stroke,
    );

    if (state == LivenessState.ready) {
      _badge(canvas, size, Icons.check, AppColors.accent);
    } else if (state == LivenessState.expired) {
      _badge(canvas, size, Icons.refresh, AppColors.warning);
    }
  }

  void _badge(Canvas canvas, Size size, IconData icon, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(size.width * 0.72, size.height * 0.68));
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.yaw != yaw || old.state != state;
}
