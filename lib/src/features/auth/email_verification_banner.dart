import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';

/// Non-blocking nudge shown to email/password users whose address is not yet
/// verified. Tapping "Resend" dispatches a fresh verification email.
///
/// Renders nothing when there is no signed-in user, the email is already
/// verified, or the account is not an email/password account (phone users have
/// no email to verify).
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _sending = false;

  /// Resolves the current FirebaseAuth user, tolerating environments where
  /// Firebase is not initialised (e.g. widget tests) by returning null.
  User? _currentUser() {
    try {
      return ref.read(firebaseAuthProvider).currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Refresh the cached emailVerified flag once on mount (e.g. after the user
    // verified in another app and came back).
    _currentUser()?.reload().then((_) {
      if (mounted) setState(() {});
    });
  }

  bool _isUnverifiedEmailUser(User? user) {
    if (user == null || user.emailVerified) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(authNotifierProvider.notifier).resendVerificationEmail();
      messenger.showSnackBar(SnackBar(content: Text(l10n.emailVerifySent)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.emailVerifyError)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser();
    if (!_isUnverifiedEmailUser(user)) return const SizedBox.shrink();

    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: oc.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oc.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_lock_outlined, size: 24, color: oc.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.emailVerifyBanner,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _resend,
                  child: Text(l10n.emailVerifyResend),
                ),
        ],
      ),
    );
  }
}
