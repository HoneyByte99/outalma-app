import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../application/auth/auth_providers.dart';
import '../../../application/auth/auth_state.dart';
import '../../../application/identity/capture_config.dart';
import '../../../application/identity/identity_capture_providers.dart';
import '../../../application/identity/identity_deposit_service.dart';
import '../../../domain/identity/identity_submit_error.dart';
import 'capture_document_page.dart';
import 'identity_error_messages.dart';
import 'selfie_liveness_page.dart';

/// Orchestrates the three captures then the deposit (archi 5.4, slice 4/5).
///
/// Sequence: recto, verso, selfie, a recap, then the three Storage uploads
/// immediately followed by the callable. Nothing is uploaded before the recap
/// confirms all three stills (E13): abandoning before the third capture leaves
/// nothing at all. A failed deposit is resumable on a fresh batch (the deposit
/// service generates a new batch id every call); a non-resumable refusal
/// (pending, already verified, rate limited, no account) routes away instead.
class IdentityCaptureFlow extends ConsumerStatefulWidget {
  const IdentityCaptureFlow({
    super.key,
    required this.onFinished,
    required this.onContactSupport,
  });

  /// Called when the journey ends: success recorded, or a terminal refusal that
  /// sends the provider back to the status/dashboard surface.
  final VoidCallback onFinished;

  /// Opens the support route after three liveness failures (AC-C34).
  final VoidCallback onContactSupport;

  @override
  ConsumerState<IdentityCaptureFlow> createState() =>
      _IdentityCaptureFlowState();
}

enum _Step { recto, verso, selfie, recap, depositing, success, failure }

class _IdentityCaptureFlowState extends ConsumerState<IdentityCaptureFlow> {
  /// Whether this state actually applied the orientation lock, so it is only
  /// ever undone by the widget that set it.
  bool _lockedOrientation = false;

  @override
  void initState() {
    super.initState();
    // The lock lives on the FLOW, not on the capture page, and that placement
    // is the whole point.
    //
    // The two document pages have different ValueKeys, so swapping recto for
    // verso makes Flutter inflate the new element (running its initState)
    // BEFORE unmounting the old one at finalizeTree. A lock taken per page
    // would therefore be RELEASED by the outgoing recto right after the verso
    // took it, leaving the second half of the journey unlocked. That is the
    // half where the shutter starts disarmed and the orientation matters most.
    //
    // It is only taken when the contour is actually drawn: without it the
    // increment would ship a visible behaviour change (Android and iPad rotate
    // freely today, nothing in AndroidManifest.xml pins them) while claiming to
    // be inert.
    if (ref.read(captureConfigProvider).contourOverlayEnabled) {
      _lockedOrientation = true;
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    if (_lockedOrientation) {
      // Restores the platform default, which is what Info.plist and the Android
      // manifest declare. A global side effect, so the restore is explicit.
      SystemChrome.setPreferredOrientations(const []);
    }
    super.dispose();
  }

  _Step _step = _Step.recto;
  Uint8List? _recto;
  Uint8List? _verso;
  Uint8List? _selfie;

  IdentitySubmitError? _error;
  bool _alreadySubmitted = false;

  void _restart() {
    setState(() {
      _step = _Step.recto;
      _recto = null;
      _verso = null;
      _selfie = null;
      _error = null;
    });
  }

  Future<void> _runDeposit() async {
    // Await the auth build rather than a bare read: the notifier may not have
    // been resolved yet on this branch, and a null read would look like a
    // missing account.
    final auth = await ref.read(authNotifierProvider.future);
    if (!mounted) return;
    final uid = auth is AuthAuthenticated ? auth.user.id : null;
    if (uid == null) {
      setState(() {
        _error = const IdentitySubmitError(
          IdentitySubmitErrorKind.accountMissing,
        );
        _step = _Step.failure;
      });
      return;
    }

    setState(() => _step = _Step.depositing);
    final service = ref.read(identityDepositServiceProvider);
    final result = await service.deposit(
      uid: uid,
      images: IdentityImages(recto: _recto!, verso: _verso!, selfie: _selfie!),
    );
    if (!mounted) return;

    switch (result) {
      case IdentityDepositSuccess(:final alreadySubmitted):
        setState(() {
          _alreadySubmitted = alreadySubmitted;
          _step = _Step.success;
        });
      case IdentityDepositFailure(:final error):
        setState(() {
          _error = error;
          _step = _Step.failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.recto:
        return CaptureDocumentPage(
          key: const ValueKey('capture-recto'),
          side: DocumentSide.recto,
          stepIndex: 1,
          onCaptured: (bytes) => setState(() {
            _recto = bytes;
            _step = _Step.verso;
          }),
        );
      case _Step.verso:
        return CaptureDocumentPage(
          key: const ValueKey('capture-verso'),
          side: DocumentSide.verso,
          stepIndex: 2,
          onCaptured: (bytes) => setState(() {
            _verso = bytes;
            _step = _Step.selfie;
          }),
        );
      case _Step.selfie:
        return SelfieLivenessPage(
          key: const ValueKey('capture-selfie'),
          stepIndex: 3,
          onContactSupport: widget.onContactSupport,
          onCaptured: (bytes) => setState(() {
            _selfie = bytes;
            _step = _Step.recap;
          }),
        );
      case _Step.recap:
        return _RecapView(
          recto: _recto!,
          verso: _verso!,
          selfie: _selfie!,
          onRetakeAll: _restart,
          onConfirm: _runDeposit,
        );
      case _Step.depositing:
        return const _DepositingView();
      case _Step.success:
        return _SuccessView(
          alreadySubmitted: _alreadySubmitted,
          onDone: widget.onFinished,
        );
      case _Step.failure:
        return _FailureView(
          error: _error!,
          onRetry: _restart,
          onLeave: widget.onFinished,
        );
    }
  }
}

/// The recap before any upload (E13): the three stills, held in memory, never
/// re-read from Storage (S5).
class _RecapView extends StatelessWidget {
  const _RecapView({
    required this.recto,
    required this.verso,
    required this.selfie,
    required this.onRetakeAll,
    required this.onConfirm,
  });

  final Uint8List recto;
  final Uint8List verso;
  final Uint8List selfie;
  final VoidCallback onRetakeAll;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.identityRecapTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.identityRecapBody),
              const SizedBox(height: AppSpacing.l),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _Thumb(bytes: recto)),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(child: _Thumb(bytes: verso)),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(child: _Thumb(bytes: selfie)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              FilledButton(
                onPressed: onConfirm,
                child: Text(l10n.identityRecapConfirm),
              ),
              const SizedBox(height: AppSpacing.s),
              TextButton(
                onPressed: onRetakeAll,
                child: Text(l10n.identityCaptureRetake),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        // A still that cannot be decoded is shown as a neutral placeholder
        // rather than throwing: the bytes still go to Storage untouched.
        errorBuilder: (context, error, stack) => ColoredBox(
          color: context.oc.inputFill,
          child: Icon(Icons.image_outlined, color: context.oc.icons),
        ),
      ),
    );
  }
}

class _DepositingView extends StatelessWidget {
  const _DepositingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.l),
            Text(l10n.identityDepositUploading),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.alreadySubmitted, required this.onDone});

  final bool alreadySubmitted;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: context.oc.success,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                l10n.identityDepositSuccessTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                alreadySubmitted
                    ? l10n.identityDepositAlreadySubmitted
                    : l10n.identityDepositSuccessBody,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onDone, child: Text(l10n.identityDone)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.error,
    required this.onRetry,
    required this.onLeave,
  });

  final IdentitySubmitError error;
  final VoidCallback onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resumable = identityErrorIsResumable(error);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: context.oc.error),
              const SizedBox(height: AppSpacing.l),
              Text(
                identitySubmitErrorMessage(l10n, error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (resumable)
                FilledButton(
                  onPressed: onRetry,
                  child: Text(l10n.identityRetry),
                )
              else
                FilledButton(
                  onPressed: onLeave,
                  child: Text(l10n.identityDone),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
