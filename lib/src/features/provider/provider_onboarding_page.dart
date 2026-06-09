import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/provider/provider_providers.dart';
import '../../data/services/geocoding_service.dart';
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

  // Geocoding state for the service-area picker.
  List<PlaceSuggestion> _suggestions = [];
  PlaceSuggestion? _selected;
  double? _selectedLat;
  double? _selectedLng;
  bool _zoneError = false;

  bool _saving = false;

  @override
  void dispose() {
    _bioController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _onZoneChanged(String input) async {
    // Any edit invalidates the previously geocoded selection.
    _selected = null;
    _selectedLat = null;
    _selectedLng = null;
    setState(() => _zoneError = false);

    if (input.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final geocoding = ref.read(geocodingServiceProvider);
      final results = await geocoding.autocomplete(input);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {
      // Suggestions are best-effort.
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _zoneController.text = suggestion.description;
    setState(() {
      _suggestions = [];
      _selected = suggestion;
      _zoneError = false;
    });

    final geocoding = ref.read(geocodingServiceProvider);
    final coords = await geocoding.getPlaceLatLng(suggestion.placeId);
    if (!mounted) return;
    setState(() {
      _selectedLat = coords?.lat;
      _selectedLng = coords?.lng;
    });
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.onboardingError;
    final errorColor = context.oc.error;

    // Service area must be geocoded — refuse to save without coordinates.
    if (_selected == null || _selectedLat == null || _selectedLng == null) {
      setState(() => _zoneError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.onboardingZoneRequired),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    setState(() => _saving = true);
    try {
      final profile = ProviderProfile(
        uid: authState.user.id,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        serviceArea: _selected!.description,
        serviceAreaLat: _selectedLat,
        serviceAreaLng: _selectedLng,
        active: true,
        suspended: false,
        createdAt: DateTime.now(),
      );
      await ref.read(providerRepositoryProvider).upsert(profile);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: errorColor),
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
    final isGeocoded = _selectedLat != null && _selectedLng != null;

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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: oc.secondaryText,
                    height: 1.5,
                  ),
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
                  decoration: InputDecoration(hintText: l10n.onboardingBioHint),
                ),
                const SizedBox(height: 20),

                // Zone — geocoded address picker
                Text(
                  l10n.onboardingZone,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _zoneController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: l10n.onboardingZoneHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    // Green check once geocoded — a visual cue requiring no text.
                    suffixIcon: isGeocoded
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: oc.success,
                            size: 20,
                          )
                        : null,
                    errorText: _zoneError ? l10n.onboardingZoneRequired : null,
                  ),
                  onChanged: _onZoneChanged,
                ),

                // Suggestions list
                if (_suggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: oc.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: oc.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: oc.border.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return InkWell(
                          onTap: () => _selectSuggestion(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: oc.secondaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.description,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Confirmation row once geocoded.
                if (isGeocoded) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 16, color: oc.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.onboardingZoneConfirmed,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: oc.success),
                        ),
                      ),
                    ],
                  ),
                ],
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
