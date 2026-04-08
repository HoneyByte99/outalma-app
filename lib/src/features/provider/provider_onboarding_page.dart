import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/provider/provider_providers.dart';
import '../../domain/models/provider_profile.dart';

class ProviderOnboardingPage extends ConsumerStatefulWidget {
  const ProviderOnboardingPage({super.key});

  @override
  ConsumerState<ProviderOnboardingPage> createState() =>
      _ProviderOnboardingPageState();
}

class _ProviderOnboardingPageState
    extends ConsumerState<ProviderOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _zoneController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bioController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final errorMsg = AppLocalizations.of(context)!.onboardingError;
    final errorColor = context.oc.error;

    setState(() => _saving = true);
    try {
      final profile = ProviderProfile(
        uid: authState.user.id,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        serviceArea: _zoneController.text.trim().isEmpty
            ? null
            : _zoneController.text.trim(),
        active: true,
        suspended: false,
        createdAt: DateTime.now(),
      );
      await ref.read(providerRepositoryProvider).upsert(profile);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.onboardingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero illustration
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: oc.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.handyman_rounded,
                    size: 72,
                    color: oc.success,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  l10n.onboardingHeadline,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingBody,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: oc.secondaryText, height: 1.5),
                ),
                const SizedBox(height: 32),

                // Bio
                Text(
                  l10n.onboardingBio,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: l10n.onboardingBioHint,
                  ),
                ),
                const SizedBox(height: 20),

                // Zone
                Text(
                  l10n.onboardingZone,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _zoneController,
                  decoration: InputDecoration(
                    hintText: l10n.onboardingZoneHint,
                    prefixIcon:
                        const Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 40),

                // CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _activate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: oc.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.onboardingActivate,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
