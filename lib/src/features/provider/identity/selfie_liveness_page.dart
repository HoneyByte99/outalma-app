import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../application/identity/capture_source.dart';
import '../../../application/identity/identity_capture_providers.dart';
import '../../../application/identity/liveness_capture.dart';
import '../../../domain/identity/liveness_challenge.dart';
import '../../shared/open_settings.dart';
import 'identity_capture_widgets.dart';
import 'liveness_face_guide.dart';

/// The selfie step with a light liveness challenge (archi 5.3, slice 5,
/// AC-C07/C08/C11/C34).
///
/// Face observations feed a pure [LivenessChallenge]; the instruction follows
/// its state. When the machine reaches `ready` (frontal again after a proven
/// turn) the shutter fires within the bounded window (archi 5.3, the default
/// sequence that stops the stream before shooting). The challenge is NEVER
/// bypassable: after three failed attempts the only escape is a support route
/// (AC-C34), no "send anyway".
///
/// TO VERIFY ON DEVICE: the real liveness against a live face, a printed photo
/// and a screen, and the delay between the frontal return and the shutter.
class SelfieLivenessPage extends ConsumerStatefulWidget {
  const SelfieLivenessPage({
    super.key,
    required this.onCaptured,
    required this.onContactSupport,
    this.stepIndex = 3,
    this.stepTotal = 3,
    this.maxAttempts = 3,
  });

  final ValueChanged<Uint8List> onCaptured;
  final VoidCallback onContactSupport;
  final int stepIndex;
  final int stepTotal;
  final int maxAttempts;

  @override
  ConsumerState<SelfieLivenessPage> createState() => _SelfieLivenessPageState();
}

enum _Ui { loading, denied, permanentlyDenied, unavailable, live, support }

class _SelfieLivenessPageState extends ConsumerState<SelfieLivenessPage> {
  late final IdentityCaptureSource _source;
  final _challenge = LivenessChallenge();
  StreamSubscription<FaceObservation>? _sub;

  _Ui _ui = _Ui.loading;
  LivenessState _state = LivenessState.waitingFace;
  int? _readyAtMs;
  int _failures = 0;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _source = ref.read(identityCaptureSourceProvider);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final permission = await _source.requestPermission();
    if (!mounted) return;
    switch (permission) {
      case CameraPermissionState.granted:
        await _startPreview();
      case CameraPermissionState.denied:
        setState(() => _ui = _Ui.denied);
      case CameraPermissionState.permanentlyDenied:
        setState(() => _ui = _Ui.permanentlyDenied);
      case CameraPermissionState.unavailable:
        setState(() => _ui = _Ui.unavailable);
    }
  }

  Future<void> _startPreview() async {
    try {
      await _source.start(CameraLensDirection.front);
    } on CaptureUnavailable {
      if (mounted) setState(() => _ui = _Ui.unavailable);
      return;
    }
    if (!mounted) return;
    _sub = _source.faceObservations().listen(_onFace);
    setState(() => _ui = _Ui.live);
  }

  void _onFace(FaceObservation observation) {
    if (_capturing) return;
    final snapshot = _challenge.offer(
      LivenessFrame(
        faceCount: observation.faceCount,
        yawAngleDeg: observation.yawAngleDeg,
        timestampMs: observation.timestampMs,
      ),
    );

    if (snapshot.isExpired) {
      _onExpired();
      return;
    }

    if (snapshot.isReady) {
      _readyAtMs ??= observation.timestampMs;
      final action = evaluateCaptureWindow(
        readyAtMs: _readyAtMs,
        nowMs: observation.timestampMs,
        lastFaceCount: observation.faceCount,
      );
      switch (action) {
        case LivenessCaptureAction.capture:
          _fire();
          return;
        case LivenessCaptureAction.abandon:
          _resetChallenge();
          return;
        case LivenessCaptureAction.wait:
          break;
      }
    }

    if (snapshot.state != _state) {
      setState(() => _state = snapshot.state);
    }
  }

  void _onExpired() {
    _failures++;
    if (_failures >= widget.maxAttempts) {
      _sub?.cancel();
      setState(() => _ui = _Ui.support);
      return;
    }
    _resetChallenge();
  }

  void _resetChallenge() {
    _challenge.reset();
    _readyAtMs = null;
    setState(() => _state = LivenessState.waitingFace);
  }

  Future<void> _fire() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final image = await _source.capture();
      if (!mounted) return;
      widget.onCaptured(image.jpegBytes);
    } on CaptureUnavailable {
      if (mounted) setState(() => _ui = _Ui.unavailable);
    } finally {
      _capturing = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _source.stop();
    super.dispose();
  }

  String _instructionFor(AppLocalizations l10n) {
    // A different second instruction after a first failure (AC-C08).
    if (_failures > 0 && _state == LivenessState.turnHead) {
      return l10n.identityLivenessRetryDifferent;
    }
    return switch (_state) {
      LivenessState.waitingFace => l10n.identityLivenessWaitingFace,
      LivenessState.multipleFaces => l10n.identityLivenessMultipleFaces,
      LivenessState.turnHead => l10n.identityLivenessTurnHead,
      LivenessState.returnToFront => l10n.identityLivenessReturnToFront,
      LivenessState.ready => l10n.identityLivenessReady,
      LivenessState.expired => l10n.identityLivenessExpired,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.identitySelfieTitle),
      ),
      body: switch (_ui) {
        _Ui.loading => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        _Ui.denied => IdentityPermissionDeniedView(
          canOpenSettings: false,
          onRetry: () {
            setState(() => _ui = _Ui.loading);
            _bootstrap();
          },
        ),
        _Ui.permanentlyDenied => const IdentityPermissionDeniedView(
          canOpenSettings: true,
          onOpenSettings: openAppSettings,
        ),
        _Ui.unavailable => const IdentityCameraUnavailableView(),
        _Ui.support => _SupportView(onContact: widget.onContactSupport),
        _Ui.live => _buildLive(context, l10n),
      },
    );
  }

  Widget _buildLive(BuildContext context, AppLocalizations l10n) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _source.buildPreview(),
        const FaceFrameOverlay(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: CaptureInstructionBanner(
            step: l10n.identityStepProgress(widget.stepIndex, widget.stepTotal),
            instruction: _instructionFor(l10n),
          ),
        ),
        // Below the oval, so the user's own face stays visible inside it. The
        // guide demonstrates the gesture the banner describes, for the many
        // providers who cannot read the sentence.
        Align(
          alignment: const Alignment(0, 0.82),
          child: LivenessFaceGuide(state: _state),
        ),
      ],
    );
  }
}

class _SupportView extends StatelessWidget {
  const _SupportView({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.support_agent_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.l),
            Text(
              l10n.identityLivenessSupportTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.identityLivenessSupportBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onContact,
              child: Text(l10n.identityContactSupport),
            ),
          ],
        ),
      ),
    );
  }
}
