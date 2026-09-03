import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../application/identity/capture_config.dart';
import '../../../application/identity/capture_source.dart';
import '../../../application/identity/document_shutter.dart';
import '../../../application/identity/document_tracker.dart';
import '../../../application/identity/identity_capture_providers.dart';
import '../../../domain/identity/document_edge_detector.dart';
import '../../../domain/identity/document_quad.dart';
import '../../../domain/identity/frame_motion.dart';
import '../../../domain/identity/luma_grid.dart';
import '../../../domain/identity/preview_projection.dart';
import '../../../domain/identity/preview_quarter_turns.dart';
import '../../../domain/identity/image_sharpness.dart';
import '../../shared/open_settings.dart';
import 'identity_capture_widgets.dart';

/// One document side captured live (archi 5.3, slice 4, AC-C05/C06/C11).
///
/// The photo is taken AUTOMATICALLY once the framing settles, so a provider who
/// cannot read has nothing to read and no button to find: a ring fills as the
/// hold runs, the shot flashes and buzzes, and an icon says what to do next.
///
/// Two things guard that automation.
///
/// The shutter starts DISARMED and only arms once the scene has moved. Without
/// it the verso screen would photograph the recto still lying there, sharp and
/// motionless, the readable-text gate would accept it since a recto carries
/// text, and the batch would ship two rectos.
///
/// The manual button stays as a FALLBACK, offered by a one-shot timer that runs
/// whether or not frames arrive, so a dead stream never leaves the user without
/// a command. When sharpness is unknown that button does not capture silently:
/// each press is refused and counted, and the AC-C34 escape only appears past
/// blurOverrideAfter, exactly as it does for a blurred frame.
///
/// TO VERIFY ON DEVICE: the calibrated thresholds (the analysis window is now
/// the centre of the frame, so their meaning changed), and the delay between
/// the decision and the shutter.
class CaptureDocumentPage extends ConsumerStatefulWidget {
  const CaptureDocumentPage({
    super.key,
    required this.side,
    required this.onCaptured,
    this.stepIndex = 1,
    this.stepTotal = 3,
  });

  final DocumentSide side;
  final ValueChanged<Uint8List> onCaptured;
  final int stepIndex;
  final int stepTotal;

  @override
  ConsumerState<CaptureDocumentPage> createState() =>
      _CaptureDocumentPageState();
}

enum _Ui { loading, denied, permanentlyDenied, unavailable, ready }

class _CaptureDocumentPageState extends ConsumerState<CaptureDocumentPage> {
  late final IdentityCaptureSource _source;

  /// Kept so it can be cancelled: [stop] closes the luma controller, so a
  /// resume that does not re-listen would leave a permanently dead screen, and
  /// a subscription outliving this page could fire on a disposed widget.
  StreamSubscription<LumaFrame>? _sub;

  /// One-shot, latched, never restarted, cancelled on dispose.
  Timer? _fallbackTimer;

  /// Drives the overlay alone, so the camera preview never rebuilds (P5).
  final ValueNotifier<DocumentShutterState> _shutter = ValueNotifier(
    const DocumentShutterState.initial(),
  );
  final ValueNotifier<int> _flashToken = ValueNotifier(0);

  /// Drives the contour alone, on the same footing as the shutter notifier, so
  /// the camera preview never rebuilds (P5).
  final ValueNotifier<DocumentTrackState> _contour = ValueNotifier(
    const DocumentTrackState.initial(),
  );

  /// The contour in PREVIEW space, or null when nothing may be drawn. Kept
  /// beside the tracker state because the projection needs the frame dimensions,
  /// which only the analysis loop sees.
  final ValueNotifier<DocumentQuad?> _projected = ValueNotifier(null);

  _Ui _ui = _Ui.loading;

  Uint8List? _lastSignature;
  int _frameIndex = 0;
  double _lastVariance = 0;

  /// False whenever the stream is not delivering. Sharpness is then UNKNOWN,
  /// never "the last value we saw", which would judge a scene nobody is
  /// looking at any more.
  bool _sharpnessKnown = false;

  /// Set between a refusal and the first frame back, so the refusal is anchored
  /// on that frame rather than on the moment of the refusal: a capture round
  /// trip costs 500 to 1000 ms, which would already have expired the hold.
  bool _awaitingResumeAnchor = false;

  /// Timestamp of the last frame analysed before a shot. Frames emitted while
  /// the shot was in flight are still queued behind it, and one of them would
  /// otherwise anchor the refusal with its OWN stale timestamp, making the
  /// refusal look older than its hold and vanish on the spot.
  int _resumeFloorMs = 0;
  int _lastFrameMs = 0;

  int _blurFails = 0;
  int _autoRejects = 0;
  bool _fallbackDue = false;
  bool _capturing = false;

  /// True once a shot has actually been taken. The hint has nothing left
  /// to teach then, and three blocks of text at once is pure noise for
  /// someone who cannot read.
  bool _anyShotTaken = false;

  bool _showBlurHint = false;
  bool _showNoTextHint = false;

  @override
  void initState() {
    super.initState();
    _source = ref.read(identityCaptureSourceProvider);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Release whatever may still be open: this runs on the retry action too,
    // and start() builds a fresh controller and stream without freeing the
    // previous ones. Safe to call more than once by contract.
    await _source.stop();
    if (!mounted) return;
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
      await _source.start(lensForSide(widget.side));
    } on CaptureUnavailable {
      if (mounted) setState(() => _ui = _Ui.unavailable);
      return;
    }
    if (!mounted) return;

    // NOT awaited, deliberately: this can run inside the luma callback's own
    // async chain (a refused shot restarts the preview from there), where
    // awaiting the cancel deadlocks the capture and leaves the button spinning
    // for ever. Dropping the await is safe because cancellation takes effect
    // synchronously; the future only reports the onCancel callback, which a
    // broadcast controller does not give us anything to wait for.
    unawaited(_sub?.cancel() ?? Future<void>.value());

    _resetAnalysis();
    _sub = _source.lumaFrames().listen(_onFrame);
    _armFallback();
    setState(() => _ui = _Ui.ready);
  }

  void _resetAnalysis() {
    _contour.value = const DocumentTrackState.initial();
    _projected.value = null;
    _frameIndex = 0;
    _lastSignature = null;
    _sharpnessKnown = false;
    _awaitingResumeAnchor = false;
    // Both frame clocks go with it: start() restarts the source's Stopwatch
    // near zero, so a floor kept from the previous epoch would silently drop
    // every incoming frame for as long as that epoch had lasted.
    _lastFrameMs = 0;
    _resumeFloorMs = 0;
    _shutter.value = const DocumentShutterState.initial();
  }

  /// The fallback clock is a wall clock, NOT the frame clock: a frame-fed clock
  /// does not advance when nothing arrives, so a dead stream would leave the
  /// user with no command at all. It is armed once and latched, so the button
  /// never disappears after showing itself.
  void _armFallback() {
    if (_fallbackTimer != null || _fallbackDue) return;
    final config = ref.read(captureConfigProvider);
    _fallbackTimer = Timer(
      Duration(milliseconds: config.manualFallbackAfterMs),
      () {
        if (mounted) setState(() => _fallbackDue = true);
      },
    );
  }

  /// Runs the contour detection for one frame, drives the overlay, and returns
  /// what the shutter should be told about the framing.
  ///
  /// Returns [DocumentFraming.unknown] on every path that is not a confident
  /// reading, and whenever `contourFramingEnabled` is off. That is what keeps
  /// this purely additive: `unknown` reproduces the pre-contour behaviour bit
  /// for bit.
  DocumentFraming _analyseContour(LumaFrame frame, CaptureConfig config) {
    // Both flags off: no grid, no Sobel, no cost. "Inert" has to mean inert in
    // milliseconds too, or the P1 and P5 budget lines move while the feature is
    // supposedly switched off.
    if (!config.contourWorkNeeded) return DocumentFraming.unknown;

    final geometry = _source.previewGeometry;
    if (geometry == null) return DocumentFraming.unknown;

    // The premise nothing in the platform guarantees: on Android the plugin
    // binds Preview and ImageAnalysis without a shared ViewPort, so a 16:9
    // plane can end up drawn over a 4:3 preview, and that contour is wrong
    // everywhere. When they disagree, draw nothing at all.
    if (!previewMatchesPlane(
      previewAspect: geometry.aspect,
      planeWidth: frame.width,
      planeHeight: frame.height,
    )) {
      _contour.value = const DocumentTrackState.initial();
      _projected.value = null;
      return DocumentFraming.unknown;
    }

    final grid = LumaGrid.sample(
      frame.luma,
      frame.width,
      frame.height,
      rowStride: frame.rowStride,
      longSide: config.contourGridLongSide,
    );
    final observation = detectDocumentEdges(
      cells: grid.cells,
      cols: grid.cols,
      rows: grid.rows,
      planeWidth: frame.width,
      planeHeight: frame.height,
      edgeThreshold: config.edgeThreshold,
      minEdgeSupport: config.minEdgeSupport,
      minFill: config.minFill,
      aspectTolerance: config.aspectTolerance,
      maxRotationDeg: config.maxRotationDeg,
    );

    final tracked = trackDocument(
      prev: _contour.value,
      observation: observation,
      smoothing: config.contourSmoothing,
      acquireFrames: config.acquireFrames,
      loseFrames: config.loseFrames,
    );
    _contour.value = tracked;

    final quad = tracked.visible ? tracked.quad : null;
    if (quad == null || !config.contourOverlayEnabled) {
      _projected.value = null;
    } else {
      final projected = projectQuadToPreview(
        quad: quad,
        quarterTurns: previewQuarterTurns(
          isIOS: geometry.isIOS,
          sensorOrientation: geometry.sensorOrientation,
        ),
      );
      // Last net against an absurd overlay: a wrong rotation gives a contour
      // that is ABSENT, never one that is grotesque, and the template is still
      // on screen either way.
      _projected.value = quadMostlyInside(projected) ? projected : null;
    }

    return config.contourFramingEnabled
        ? observation.framing
        : DocumentFraming.unknown;
  }

  void _onFrame(LumaFrame frame) {
    if (!mounted) return;
    // The clock of the most recent frame, kept for the resume floor. NOT a
    // running maximum: start() restarts the source's Stopwatch near zero, and
    // a maximum would carry the previous epoch's values across the restart and
    // then drop every new frame as stale.
    _lastFrameMs = frame.timestampMs;
    if (_capturing) return;

    final config = ref.read(captureConfigProvider);

    // Drop whatever was in flight when the shot was taken: only a frame from
    // AFTER the resume may anchor the refusal.
    if (_awaitingResumeAnchor && frame.timestampMs <= _resumeFloorMs) return;

    // One frame in N, but the first frame after every anchor is always read:
    // a pre-incremented counter would drop the two frames that carry the
    // arming and the start of the hold.
    if (_frameIndex++ % config.analyzeEveryNthFrame != 0) return;

    final signature = FrameMotion.sample(
      frame.luma,
      frame.width,
      frame.height,
      rowStride: frame.rowStride,
      centerFraction: config.analysisCenterFraction,
    );
    final previous = _lastSignature;
    _lastSignature = signature;
    // The very first frame has nothing to compare against: no evidence of
    // movement, so the shutter stays disarmed.
    final motion = previous == null
        ? 0.0
        : FrameMotion.meanAbsoluteDifference(previous, signature);

    _lastVariance = ImageSharpness.laplacianVariance(
      frame.luma,
      frame.width,
      frame.height,
      rowStride: frame.rowStride,
      centerFraction: config.analysisCenterFraction,
    );
    _sharpnessKnown = true;

    final framing = _analyseContour(frame, config);

    var previousState = _shutter.value;
    if (_awaitingResumeAnchor) {
      _awaitingResumeAnchor = false;
      previousState = DocumentShutterState(
        reason: DocumentShutterReason.refused,
        refusedSinceMs: frame.timestampMs,
      );
    }

    final next = evaluateDocumentShutter(
      prev: previousState,
      sharpness: _lastVariance,
      motion: motion,
      nowMs: frame.timestampMs,
      sharpnessThreshold: config.sharpnessThresholdFor(widget.side),
      motionThreshold: config.motionThreshold,
      steadyHoldMs: config.steadyHoldMs,
      refusedHoldMs: config.refusedHoldMs,
      framing: framing,
      framingGraceMs: config.framingGraceMs,
    );
    _shutter.value = next;

    // Once the refusal has had its time on screen, drop its message too.
    if (next.reason != DocumentShutterReason.refused &&
        (_showNoTextHint || _showBlurHint)) {
      setState(() {
        _showNoTextHint = false;
        _showBlurHint = false;
      });
    }

    if (next.shouldCapture &&
        autoShutterEnabled(
          autoRejects: _autoRejects,
          rejectLimit: config.autoRejectLimit,
        )) {
      unawaited(_capture(automatic: true));
    }
  }

  /// [automatic] shots have already cleared the sharpness bar inside the
  /// shutter selector. [force] is the AC-C34 escape, which skips the sharpness
  /// bar but never the readable-text gate.
  Future<void> _capture({required bool automatic, bool force = false}) async {
    if (_capturing) return;
    final config = ref.read(captureConfigProvider);

    if (!automatic && !force) {
      // Unknown sharpness counts as NOT sharp. Capturing anyway would drop the
      // AC-C06 barrier after zero refusals, which is a bypass wearing the
      // escape's label rather than the escape itself.
      final sharp =
          _sharpnessKnown &&
          _lastVariance >= config.sharpnessThresholdFor(widget.side);
      if (!sharp) {
        setState(() {
          _blurFails++;
          _showBlurHint = true;
          _showNoTextHint = false;
        });
        return;
      }
    }

    setState(() {
      _capturing = true;
      _showNoTextHint = false;
      _showBlurHint = false;
    });
    // The stream stops for the shot: nothing may be judged until it is back.
    _sharpnessKnown = false;
    // Pinned here, on the frame that triggered this shot, rather than at
    // resume time: by then a straggler from a previous epoch could have moved
    // it, and the screen would drop every new frame until the restarted clock
    // caught up.
    _resumeFloorMs = _lastFrameMs;

    try {
      final image = await _source.capture();
      if (!mounted) return;

      // A photo was taken. Say so on two channels that need no reading, before
      // knowing whether it will be kept.
      _flashToken.value++;
      _anyShotTaken = true;
      unawaited(HapticFeedback.mediumImpact());

      // Readable-text gate (AC-C06b): a sharp still is not necessarily a
      // document. Refuse any still on which no text at all was recognised, even
      // on the "send anyway" path, so a crisp photo of anything but an ID card
      // (a wall, a hand, a cow) never reaches the reviewer.
      final textResult = await ref
          .read(documentTextDetectorProvider)
          .detect(image.jpegBytes);
      if (!mounted) return;
      if (!textResult.hasText) {
        _autoRejects++;
        setState(() => _showNoTextHint = true);
        await _resumeAfterRefusal();
        return;
      }

      widget.onCaptured(image.jpegBytes);
    } on CaptureUnavailable {
      if (mounted) setState(() => _ui = _Ui.unavailable);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Brings the preview back after a REFUSED still, never after an accepted one
  /// (the page is being torn down then, and restarting a stream on a controller
  /// about to be disposed is what breaks on entry-level Android).
  Future<void> _resumeAfterRefusal() async {
    try {
      await _source.resumeStream();
    } on CaptureUnavailable {
      // Restarting the stream is not universal. Reopen the camera outright
      // before degrading anything: _startPreview cancels the old subscription
      // and re-listens, which is required because stop() closed the stream.
      await _source.stop();
      if (!mounted) return;
      await _startPreview();
      return;
    }
    if (!mounted) return;
    _frameIndex = 0;
    _lastSignature = null;
    _awaitingResumeAnchor = true;
    _shutter.value = const DocumentShutterState.refused();
  }

  @override
  void dispose() {
    // Order matters: silence the inputs before disposing what they write to.
    _fallbackTimer?.cancel();
    _contour.dispose();
    _projected.dispose();
    _sub?.cancel();
    _source.stop();
    _shutter.dispose();
    _flashToken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.side == DocumentSide.recto
        ? l10n.identityCaptureRectoTitle
        : l10n.identityCaptureVersoTitle;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
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
        // Always reachable again (U1): this state can now be entered mid
        // journey, after the recto is already in hand, so a terminal screen
        // would strand the user.
        _Ui.unavailable => IdentityCameraUnavailableView(onRetry: _bootstrap),
        _Ui.ready => _buildLive(context, l10n),
      },
    );
  }

  /// The one message the screen shows, rendered in a single place so the
  /// refusal icon ADDS to the reason rather than replacing it.
  String _message(AppLocalizations l10n, DocumentShutterState state) {
    if (_showNoTextHint) return l10n.identityCaptureNoText;
    if (_showBlurHint) return l10n.identityCaptureBlurry;
    return switch (state.reason) {
      DocumentShutterReason.noFrame => l10n.identityCaptureSearching,
      DocumentShutterReason.waitingForMotion =>
        widget.side == DocumentSide.verso
            ? l10n.identityCaptureFlipCard
            : l10n.identityCaptureSearching,
      DocumentShutterReason.tooBlurred => l10n.identityCaptureBlurry,
      DocumentShutterReason.moving => l10n.identityCaptureMoving,
      DocumentShutterReason.steadying => l10n.identityCaptureHoldStill,
      DocumentShutterReason.ready => l10n.identityCaptureHoldStill,
      DocumentShutterReason.refused => l10n.identityCaptureRefused,
      DocumentShutterReason.noDocument => l10n.identityCaptureNoDocument,
      DocumentShutterReason.tooSmall => l10n.identityCaptureTooSmall,
      DocumentShutterReason.tooClose => l10n.identityCaptureTooClose,
    };
  }

  Widget _buildLive(BuildContext context, AppLocalizations l10n) {
    final config = ref.read(captureConfigProvider);
    final instruction = widget.side == DocumentSide.recto
        ? l10n.identityCaptureRectoInstruction
        : l10n.identityCaptureVersoInstruction;

    return Stack(
      fit: StackFit.expand,
      children: [
        _source.buildPreview(),
        // FULL-BLEED, deliberately: the AspectRatio CameraPreview wraps itself
        // in is inert under this expanded Stack, so the texture is stretched
        // over the whole rectangle and normalised plane coordinates map onto it
        // linearly. Wrapping this in a Center or an AspectRatio would introduce
        // the very letterbox it looks like it is correcting.
        ValueListenableBuilder<DocumentShutterState>(
          valueListenable: _shutter,
          builder: (context, state, _) => ValueListenableBuilder<DocumentQuad?>(
            valueListenable: _projected,
            builder: (context, quad, _) => DocumentContourOverlay(
              quad: quad,
              color: colorFor(state.reason),
            ),
          ),
        ),
        ValueListenableBuilder<DocumentShutterState>(
          valueListenable: _shutter,
          builder: (context, state, _) => ValueListenableBuilder<DocumentQuad?>(
            valueListenable: _projected,
            builder: (context, quad, _) => DocumentFrameOverlay(
              reason: state.reason,
              progress: state.progress,
              showFlipDemo: widget.side == DocumentSide.verso,
              contourVisible: quad != null,
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _flashToken,
          builder: (context, token, _) => token == 0
              ? const SizedBox.shrink()
              : TweenAnimationBuilder<double>(
                  key: ValueKey(token),
                  tween: Tween(begin: 0.85, end: 0),
                  duration: const Duration(milliseconds: 240),
                  builder: (context, opacity, _) => IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: CaptureInstructionBanner(
            step: l10n.identityStepProgress(widget.stepIndex, widget.stepTotal),
            instruction: instruction,
            hint: _anyShotTaken ? null : l10n.identityCaptureAutoHint,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<DocumentShutterState>(
            valueListenable: _shutter,
            builder: (context, state, _) => _BottomBar(
              capturing: _capturing,
              message: _message(l10n, state),
              captureLabel: l10n.identityCaptureButton,
              manualHint: l10n.identityCaptureManualHint,
              sendAnywayLabel: l10n.identityCaptureSendAnyway,
              offerManual: offerManualShutter(
                fallbackDue: _fallbackDue,
                autoRejects: _autoRejects,
                rejectLimit: config.autoRejectLimit,
              ),
              offerSendAnyway: _blurFails >= config.blurOverrideAfter,
              onCapture: () => _capture(automatic: false),
              onSendAnyway: () => _capture(automatic: false, force: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.capturing,
    required this.message,
    required this.captureLabel,
    required this.manualHint,
    required this.sendAnywayLabel,
    required this.offerManual,
    required this.offerSendAnyway,
    required this.onCapture,
    required this.onSendAnyway,
  });

  final bool capturing;
  final String message;
  final String captureLabel;
  final String manualHint;
  final String sendAnywayLabel;
  final bool offerManual;
  final bool offerSendAnyway;
  final VoidCallback onCapture;
  final VoidCallback onSendAnyway;

  @override
  Widget build(BuildContext context) {
    return Container(
      // A7: text on a camera preview sits on a scrim of at least 60 percent.
      color: Colors.black.withValues(alpha: 0.6),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            if (offerManual) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                manualHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.s),
              Semantics(
                button: true,
                label: captureLabel,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: capturing ? null : onCapture,
                    child: capturing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(captureLabel),
                  ),
                ),
              ),
              if (offerSendAnyway)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s),
                  child: TextButton(
                    onPressed: capturing ? null : onSendAnyway,
                    child: Text(
                      sendAnywayLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
