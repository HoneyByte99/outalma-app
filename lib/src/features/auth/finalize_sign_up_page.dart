import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../application/auth/auth_providers.dart';

/// Recovery screen shown when a signed-in account has no server-side consent
/// record (the sign-up consent Cloud Function AND its rollback both failed).
///
/// The router's consent-presence gate lands the zombie account here instead of
/// letting it into the app. From here the user can retry the consent write, or
/// sign out to start over. Legally (CDP Senegal loi 2008-12 art. 11 / RGPD) the
/// account must not be usable until consent is persisted server-side.
class FinalizeSignUpPage extends ConsumerStatefulWidget {
  const FinalizeSignUpPage({super.key});

  @override
  ConsumerState<FinalizeSignUpPage> createState() => _FinalizeSignUpPageState();
}

class _FinalizeSignUpPageState extends ConsumerState<FinalizeSignUpPage> {
  bool _loading = false;
  String? _error;

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).retryConsentFinalization();
      // On success the auth state refreshes and the router leaves this screen.
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'La finalisation a echoue. Verifiez votre connexion et reessayez.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalisez votre inscription')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user_outlined, size: 56),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Votre inscription doit etre finalisee',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s),
              const Text(
                'Nous devons enregistrer votre acceptation des conditions '
                'avant de continuer. Reessayez, ou deconnectez-vous pour '
                'recommencer.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.m),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.l),
              FilledButton(
                onPressed: _loading ? null : _retry,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Reessayer'),
              ),
              const SizedBox(height: AppSpacing.s),
              TextButton(
                onPressed: _loading ? null : _signOut,
                child: const Text('Se deconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
