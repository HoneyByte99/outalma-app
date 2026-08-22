import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/app_spacing.dart';
import '../../../application/auth/auth_providers.dart';
import '../../../application/auth/auth_state.dart';
import 'identity_capture_flow.dart';

/// Hosts [IdentityCaptureFlow] and wires its two exits to navigation.
///
/// The flow itself is camera and state only (already built and tested); this
/// host owns what happens at its edges: a finished journey returns to the
/// status screen, and the liveness support exit opens a contact path.
class IdentityCaptureHostPage extends ConsumerWidget {
  const IdentityCaptureHostPage({super.key, required this.onFinished});

  /// Leaves the capture journey (typically back to the status screen).
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IdentityCaptureFlow(
      onFinished: onFinished,
      onContactSupport: () => _showSupport(context, ref),
    );
  }

  // The liveness support exit after three failures (AC-C34, E17b). The full
  // design routes this to WhatsApp with an opaque account reference, but the
  // support number is not configured yet (see the report's open questions), so
  // this shows the reference to copy rather than dead-ending on a fake link.
  void _showSupport(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.read(authNotifierProvider).valueOrNull;
    final ref0 = auth is AuthAuthenticated ? auth.user.id : '';
    // An opaque reference, never a name or a card number (design section 6).
    final reference = ref0.length >= 6 ? ref0.substring(0, 6) : ref0;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.identityLivenessSupportTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.identityLivenessSupportBody),
            const SizedBox(height: AppSpacing.m),
            SelectableText(
              l10n.identitySupportReference(reference),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.identityDone),
          ),
        ],
      ),
    );
  }
}
