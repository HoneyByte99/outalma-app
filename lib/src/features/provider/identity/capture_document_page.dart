import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../application/identity/capture_config.dart';
import '../../../application/identity/capture_source.dart';
import '../../../application/identity/identity_capture_providers.dart';
import '../../../domain/identity/image_sharpness.dart';
import '../../shared/open_settings.dart';
import 'identity_capture_widgets.dart';

/// One document side captured live (archi 5.3, slice 4, AC-C05/C06/C11).
///
/// The sharpness gate runs on the luminance stream BEFORE anything is shot: the
/// capture button only fires when the latest frame is sharp enough, or when the
/// user takes the "send anyway" escape after two blur refusals on this same
/// still (AC-C34, never offered on the liveness challenge). The recto threshold
/// is strictly harder than the verso's (AC-C06).
///
/// TO VERIFY ON DEVICE: the live preview render and the calibrated threshold.
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
  _Ui _ui = _Ui.loading;
  double _lastVariance = 0;
  int _blurFails = 0;
  bool _capturing = false;
  bool _showBlurHint = false;
  bool _showNoTextHint = false;

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
      await _source.start(lensForSide(widget.side));
    } on CaptureUnavailable {
      if (mounted) setState(() => _ui = _Ui.unavailable);
      return;
    }
    if (!mounted) return;
    _source.lumaFrames().listen((frame) {
      _lastVariance = ImageSharpness.laplacianVariance(
        frame.luma,
        frame.width,
        frame.height,
        rowStride: frame.rowStride,
      );
    });
    setState(() => _ui = _Ui.ready);
  }

  Future<void> _onCapturePressed({bool force = false}) async {
    if (_capturing) return;
    final config = ref.read(captureConfigProvider);
    final threshold = config.sharpnessThresholdFor(widget.side);

    if (!force && _lastVariance < threshold) {
      setState(() {
        _blurFails++;
        _showBlurHint = true;
      });
      return;
    }

    setState(() {
      _capturing = true;
      _showNoTextHint = false;
    });
    try {
      final image = await _source.capture();
      if (!mounted) return;

      // Readable-text gate (AC-C06b): a sharp still is not necessarily a
      // document. Refuse any still on which no text at all was recognised, even
      // on the "send anyway" path, so a crisp photo of anything but an ID card
      // (a wall, a hand, a cow) never reaches the reviewer.
      final textResult = await ref
          .read(documentTextDetectorProvider)
          .detect(image.jpegBytes);
      if (!mounted) return;
      if (!textResult.hasText) {
        setState(() => _showNoTextHint = true);
        return;
      }

      widget.onCaptured(image.jpegBytes);
    } on CaptureUnavailable {
      if (mounted) setState(() => _ui = _Ui.unavailable);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _source.stop();
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
        _Ui.unavailable => const IdentityCameraUnavailableView(),
        _Ui.ready => _buildLive(context, l10n),
      },
    );
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
        const DocumentFrameOverlay(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: CaptureInstructionBanner(
            step: l10n.identityStepProgress(widget.stepIndex, widget.stepTotal),
            instruction: instruction,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            capturing: _capturing,
            showBlurHint: _showBlurHint,
            blurMessage: l10n.identityCaptureBlurry,
            showNoTextHint: _showNoTextHint,
            noTextMessage: l10n.identityCaptureNoText,
            captureLabel: l10n.identityCaptureButton,
            sendAnywayLabel: l10n.identityCaptureSendAnyway,
            offerSendAnyway: _blurFails >= config.blurOverrideAfter,
            onCapture: () => _onCapturePressed(),
            onSendAnyway: () => _onCapturePressed(force: true),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.capturing,
    required this.showBlurHint,
    required this.blurMessage,
    required this.showNoTextHint,
    required this.noTextMessage,
    required this.captureLabel,
    required this.sendAnywayLabel,
    required this.offerSendAnyway,
    required this.onCapture,
    required this.onSendAnyway,
  });

  final bool capturing;
  final bool showBlurHint;
  final String blurMessage;
  final bool showNoTextHint;
  final String noTextMessage;
  final String captureLabel;
  final String sendAnywayLabel;
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
            if (showNoTextHint)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.m),
                child: Text(
                  noTextMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            else if (showBlurHint)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.m),
                child: Text(
                  blurMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
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
        ),
      ),
    );
  }
}
