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
  bool _geocodingZone = false;
  bool _geocodeFailed = false;

  bool _saving = false;

  // Daily working-hours window the client's booking picker uses to offer slots.
  int _hourStart = kDefaultWorkingHourStart;
  int _hourEnd = kDefaultWorkingHourEnd;

  @override
  void initState() {
    super.initState();
    // Prefill from an existing profile (lazy onboarding sends incomplete
    // providers back here): keep the bio and working hours they already have.
    final existing = ref.read(currentProviderProfileProvider).valueOrNull;
    if (existing != null) {
      if ((existing.bio ?? '').isNotEmpty) _bioController.text = existing.bio!;
      _hourStart = existing.effectiveHourStart;
      _hourEnd = existing.effectiveHourEnd;
    }
  }

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
    setState(() {
      _zoneError = false;
      _geocodeFailed = false;
    });

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
      _geocodeFailed = false;
      _geocodingZone = true;
    });

    final l10n = AppLocalizations.of(context)!;
    final geocoding = ref.read(geocodingServiceProvider);
    try {
      final coords = await geocoding.getPlaceLatLng(suggestion.placeId);
      if (!mounted) return;
      if (coords == null) {
        setState(() {
          _geocodingZone = false;
          _geocodeFailed = true;
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.zoneGeocodeFailed),
              backgroundColor: context.oc.error,
            ),
          );
        return;
      }
      setState(() {
        _selectedLat = coords.lat;
        _selectedLng = coords.lng;
        _geocodingZone = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _geocodingZone = false;
        _geocodeFailed = true;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.zoneGeocodeFailed),
            backgroundColor: context.oc.error,
          ),
        );
    }
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
        workingHourStart: _hourStart,
        workingHourEnd: _hourEnd,
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
                    // Spinner while resolving, then green check once geocoded —
                    // visual cues requiring no text.
                    suffixIcon: _geocodingZone
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : isGeocoded
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: oc.success,
                            size: 20,
                          )
                        : null,
                    errorText: _zoneError
                        ? l10n.onboardingZoneRequired
                        : _geocodeFailed
                        ? l10n.zoneGeocodeFailed
                        : null,
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
                        return Semantics(
                          button: true,
                          label: s.description,
                          child: InkWell(
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
                const SizedBox(height: 24),

                // Working hours — drives the slots the client can book.
                Text(
                  l10n.onboardingHours,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.onboardingHoursHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _HourField(
                        label: l10n.onboardingHoursStart,
                        value: _hourStart,
                        onChanged: (v) => setState(() {
                          _hourStart = v;
                          if (_hourEnd <= _hourStart) {
                            _hourEnd = (_hourStart + 1).clamp(1, 23);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HourField(
                        label: l10n.onboardingHoursEnd,
                        value: _hourEnd,
                        onChanged: (v) => setState(() {
                          _hourEnd = v <= _hourStart ? _hourStart + 1 : v;
                        }),
                      ),
                    ),
                  ],
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

/// A 24h hour picker (00:00 … 23:00) used for the working-hours window.
class _HourField extends StatelessWidget {
  const _HourField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      // Key by value so a programmatic change (auto-bump of the end hour)
      // rebuilds the field with the new selection.
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var h = 0; h < 24; h++)
          DropdownMenuItem(
            value: h,
            child: Text('${h.toString().padLeft(2, '0')}:00'),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
