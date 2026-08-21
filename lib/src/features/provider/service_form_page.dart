import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/pricing/pricing_providers.dart';
import '../../application/service/service_providers.dart';
import '../../core/utils/format_utils.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/service_photo_upload_service.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/pricing/pricing_config.dart';
import '../shared/category_icon.dart';
import '../../domain/models/service.dart';
import '../../domain/models/service_zone.dart';

class ServiceFormPage extends ConsumerStatefulWidget {
  /// Pass an existing service to edit. Null = create mode.
  const ServiceFormPage({super.key, this.existing});

  final Service? existing;

  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  // For hourly/daily this is the single price; for monthly it is the low end
  // of the range (the high end lives in [_priceMaxController]).
  late final TextEditingController _priceController;
  late final TextEditingController _priceMaxController;
  late CategoryId _category;
  late PriceType _priceType;
  // Extra tasks the listing also covers, beyond the main category. Never
  // contains the main category; capped at the grid's maxExtraTasks.
  late Set<String> _extraTasks;
  late bool _published;
  List<String> _photos = [];
  List<ServiceZone> _zones = [];
  bool _uploadingPhoto = false;
  late final String _pendingServiceId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _titleController = TextEditingController(text: s?.title ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _priceController = TextEditingController(
      text: s != null ? s.price.toString() : '',
    );
    _priceMaxController = TextEditingController(
      text: s?.priceMax != null ? s!.priceMax.toString() : '',
    );
    _category = s?.categoryId ?? CategoryId.menage;
    // Legacy fixed listings are treated as daily (spec decision 11); the
    // migration rewrites them in the database, the form does so on next save.
    _priceType = s == null
        ? PriceType.hourly
        : (s.priceType == PriceType.fixed ? PriceType.daily : s.priceType);
    _extraTasks = {...?s?.extraTasks};
    _published = s?.published ?? false;
    _photos = List<String>.from(s?.photos ?? []);
    _zones = List<ServiceZone>.from(s?.serviceZones ?? []);
    _pendingServiceId = _isEdit
        ? widget.existing!.id
        : FirebaseFirestore.instance.collection('services').doc().id;
  }

  // Captured so we can clear our snackbars on dispose (the messenger is an
  // ancestor that outlives this page) - otherwise the photo-removed "undo"
  // snackbar lingers onto the next screen after pop/back.
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _messenger?.clearSnackBars();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  // A service carries a single photo. The model stays a List<String> for
  // backward compatibility with services created earlier (which may hold more),
  // but the form caps new input at one: once a photo is added the "add more"
  // tile disappears.
  static const int _maxPhotos = 1;

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final photoErrorMsg = l10n.serviceFormPhotoError;
    final maxReachedMsg = l10n.serviceFormPhotoMax(_maxPhotos);
    final errorColor = context.oc.error;

    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(maxReachedMsg), backgroundColor: errorColor),
      );
      return;
    }

    final uploader = ref.read(servicePhotoUploadServiceProvider);
    setState(() => _uploadingPhoto = true);
    try {
      final url = await uploader.pickAndUpload(_pendingServiceId);
      if (url != null && mounted) {
        setState(() => _photos = [..._photos, url]);
      }
    } catch (e, st) {
      debugPrint('[ServicePhoto] pickAndUpload failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(photoErrorMsg), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _removePhoto(int index) {
    final l10n = AppLocalizations.of(context)!;
    final removed = _photos[index];
    setState(() => _photos = [..._photos]..removeAt(index));

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    var undone = false;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.serviceFormPhotoRemoved),
        action: SnackBarAction(
          label: l10n.serviceFormPhotoUndo,
          onPressed: () {
            undone = true;
            if (mounted) {
              setState(
                () =>
                    _photos = [..._photos]
                      ..insert(index.clamp(0, _photos.length), removed),
              );
            }
          },
        ),
      ),
    );

    // Delete from storage only once the undo window has closed, so an undone
    // removal keeps the photo intact. Best-effort: ignore failures.
    controller.closed
        .then((_) {
          if (undone) return;
          ref
              .read(servicePhotoUploadServiceProvider)
              .deletePhotoByUrl(removed)
              .catchError((_) {});
        })
        .catchError((_) {});
  }

  void _removeZone(int index) {
    setState(() => _zones = [..._zones]..removeAt(index));
  }

  Future<void> _showAddZoneSheet() async {
    final zone = await showModalBottomSheet<ServiceZone>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _AddZoneSheet(geocoding: ref.read(geocodingServiceProvider)),
    );
    if (zone != null && mounted) {
      setState(() => _zones = [..._zones, zone]);
    }
  }

  Future<void> _editZone(int index) async {
    final updated = await showModalBottomSheet<ServiceZone>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddZoneSheet(
        geocoding: ref.read(geocodingServiceProvider),
        existing: _zones[index],
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _zones = [..._zones]..[index] = updated;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    final zonesRequiredMsg = l10n.serviceFormZonesRequired;
    final saveErrorMsg = l10n.serviceFormSaveError;
    final errorColor = context.oc.error;

    if (_zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(zonesRequiredMsg), backgroundColor: errorColor),
      );
      return;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    // Publishing is not gated on onboarding - providers are active by default.
    // Only a suspended provider is blocked, which the server rule enforces.

    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final isMonthly = _priceType == PriceType.monthly;
    // Monthly stores the range: price = low end, priceMax = high end. The other
    // modes carry no priceMax; the server rule rejects a priceMax outside the
    // monthly mode, so it must be cleared (not just left stale) when switching.
    final priceMax = isMonthly
        ? (int.tryParse(_priceMaxController.text.trim()) ?? 0)
        : null;
    // Only bounded categories carry extra tasks; a legacy non-launch listing
    // keeps none. Never include the main category in its own extras.
    final config = ref.read(pricingConfigProvider).valueOrNull;
    final extraTasks = (config?.isBounded(_category.name) ?? false)
        ? (_extraTasks.where((t) => t != _category.name).toList()..sort())
        : const <String>[];

    setState(() => _saving = true);
    try {
      final repo = ref.read(serviceRepositoryProvider);
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          categoryId: _category,
          priceType: _priceType,
          price: price,
          priceMax: priceMax,
          extraTasks: extraTasks,
          serviceZones: _zones,
          photos: _photos,
          published: _published,
          updatedAt: DateTime.now(),
        );
        await repo.update(updated);
      } else {
        final now = DateTime.now();
        final service = Service(
          id: _pendingServiceId,
          providerId: authState.user.id,
          categoryId: _category,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          photos: _photos,
          priceType: _priceType,
          price: price,
          priceMax: priceMax,
          extraTasks: extraTasks,
          published: _published,
          serviceZones: _zones,
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(service);
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(saveErrorMsg), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- Pricing section ----------------------------------------------------

  CategoryId? _categoryFromName(String name) {
    for (final c in CategoryId.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Categories offered in the selector: the bounded launch tasks, plus the
  /// current category when editing a legacy non-launch listing so it stays
  /// editable (SC-13). Falls back to the current category alone while the grid
  /// is still loading (save is disabled in that state anyway).
  List<CategoryId> _selectableCategories(PricingConfig? config) {
    if (config == null) return [_category];
    final bounded = config.boundedCategories
        .map(_categoryFromName)
        .whereType<CategoryId>()
        .toList();
    if (!bounded.contains(_category)) bounded.insert(0, _category);
    return bounded;
  }

  void _toggleExtra(String name, bool selected, int maxExtra) {
    setState(() {
      if (selected) {
        if (_extraTasks.length < maxExtra) _extraTasks.add(name);
      } else {
        _extraTasks.remove(name);
      }
    });
  }

  Widget _buildPricing(
    AppLocalizations l10n,
    OutalmaColors oc,
    AsyncValue<PricingConfig> pricingAsync,
  ) {
    return pricingAsync.when(
      loading: () => const _PricingLoading(),
      error: (_, __) => _PricingError(
        message: l10n.serviceFormPricingUnavailable,
        retryLabel: l10n.retry,
        onRetry: () => ref.invalidate(pricingConfigProvider),
      ),
      data: (config) => config.isBounded(_category.name)
          ? _buildBoundedPricing(l10n, oc, config)
          : _buildFreePrice(l10n),
    );
  }

  /// Legacy non-launch category: unbounded, single free price, no extra tasks
  /// (spec section 4, SC-13 / SC-22).
  Widget _buildFreePrice(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.serviceFormPrice),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(hintText: '0', suffixText: 'F CFA'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null || n <= 0) return l10n.serviceFormPriceInvalid;
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBoundedPricing(
    AppLocalizations l10n,
    OutalmaColors oc,
    PricingConfig config,
  ) {
    final isMonthly = _priceType == PriceType.monthly;
    final bounds = config.boundsFor(_priceType)!;
    // Monthly carries no extra-task bonus, so its ceiling is the flat max; the
    // other modes lift the ceiling by extraBonusPercent per extra task.
    final cap = bounds.capFor(_extraTasks.length);
    final rangeText = isMonthly
        ? l10n.serviceFormPriceRange(
            formatAmount(bounds.min),
            formatAmount(bounds.max),
          )
        : l10n.serviceFormPriceRange(
            formatAmount(bounds.min),
            formatAmount(cap),
          );

    final extraOptions = config.boundedCategories
        .where((name) => name != _category.name)
        .map(_categoryFromName)
        .whereType<CategoryId>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.serviceFormBillingMode),
        _ModeSelector(
          value: _priceType,
          onChanged: (t) => setState(() => _priceType = t),
        ),
        const SizedBox(height: 20),

        _Label(l10n.serviceFormPrice),
        // The allowed range, always visible before any input (AC-01) and
        // updated live as the mode or extra tasks change (AC-03, AC-06).
        Text(
          rangeText,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 8),
        if (isMonthly)
          _buildMonthlyFields(l10n, bounds)
        else
          _buildSinglePrice(l10n, bounds, cap),
        const SizedBox(height: 20),

        _Label(l10n.serviceFormExtraTasks),
        Text(
          l10n.serviceFormExtraTasksSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 8),
        _ExtraTasksSelector(
          options: extraOptions,
          selected: _extraTasks,
          maxExtra: config.maxExtraTasks,
          limitLabel: l10n.serviceFormExtraTasksMax,
          onToggle: (name, sel) =>
              _toggleExtra(name, sel, config.maxExtraTasks),
        ),
      ],
    );
  }

  Widget _buildSinglePrice(
    AppLocalizations l10n,
    PricingModeBounds bounds,
    int cap,
  ) {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: const InputDecoration(hintText: '0', suffixText: 'F CFA'),
      validator: (v) {
        final n = int.tryParse((v ?? '').trim());
        if (n == null) return l10n.serviceFormPriceRequired;
        if (n < bounds.min || n > cap) {
          return l10n.serviceFormPriceOutOfRange(
            formatAmount(bounds.min),
            formatAmount(cap),
          );
        }
        return null;
      },
    );
  }

  Widget _buildMonthlyFields(AppLocalizations l10n, PricingModeBounds bounds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.serviceFormPriceMonthlyMin),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(hintText: '0', suffixText: 'F CFA'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return l10n.serviceFormPriceRequired;
            if (n < bounds.min || n > bounds.max) {
              return l10n.serviceFormPriceOutOfRange(
                formatAmount(bounds.min),
                formatAmount(bounds.max),
              );
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _Label(l10n.serviceFormPriceMonthlyMax),
        TextFormField(
          controller: _priceMaxController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(hintText: '0', suffixText: 'F CFA'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return l10n.serviceFormPriceRequired;
            if (n < bounds.min || n > bounds.max) {
              return l10n.serviceFormPriceOutOfRange(
                formatAmount(bounds.min),
                formatAmount(bounds.max),
              );
            }
            final min = int.tryParse(_priceController.text.trim());
            if (min != null && n < min) {
              return l10n.serviceFormMonthlyMaxBelowMin;
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final pricingAsync = ref.watch(pricingConfigProvider);
    // The grid is the single source of the ranges the form enforces. Until it
    // loads (or if it fails), publishing is disabled and the pricing section
    // shows a loading/error state (archi section 5, spec AC-15 / SC-12).
    final config = pricingAsync.valueOrNull;
    final canSave = !_saving && config != null;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.serviceFormEditTitle : l10n.serviceFormCreateTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: ElevatedButton(
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEdit ? l10n.serviceFormSave : l10n.serviceFormCreate),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Photo upload
              _PhotoSection(
                photos: _photos,
                uploading: _uploadingPhoto,
                maxPhotos: _maxPhotos,
                onPick: _pickPhoto,
                onRemove: _removePhoto,
              ),
              const SizedBox(height: 20),

              // Title
              _Label(l10n.serviceFormTitleLabel),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.serviceFormTitleHint,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.serviceFormTitleRequired
                    : null,
              ),
              const SizedBox(height: 20),

              // Category. Only the bounded launch tasks are creatable; the five
              // non-launch categories are hidden at creation (spec section 4,
              // SC-13). An existing non-launch listing keeps its category so it
              // stays editable.
              _Label(l10n.serviceFormCategory),
              _CategorySelector(
                value: _category,
                selectable: _selectableCategories(config),
                onChanged: (c) => setState(() {
                  _category = c;
                  // A category can never be its own extra task.
                  _extraTasks.remove(c.name);
                }),
              ),
              const SizedBox(height: 20),

              // Description
              _Label(l10n.serviceFormDescription),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.serviceFormDescriptionHint,
                ),
              ),
              const SizedBox(height: 20),

              // Pricing: billing mode, encadre range, extra tasks. The whole
              // section is driven by the grid; it renders loading/error states
              // when the grid is unavailable (spec AC-15, SC-12).
              _buildPricing(l10n, oc, pricingAsync),
              const SizedBox(height: 20),

              // Zones d'intervention
              _Label(l10n.serviceFormZones),
              _ZonesSection(
                zones: _zones,
                onRemove: _removeZone,
                onEdit: _editZone,
                onAdd: _showAddZoneSheet,
              ),
              const SizedBox(height: 24),

              // Published toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: oc.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: oc.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.serviceFormPublish,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.serviceFormPublishSubtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: oc.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _published,
                      onChanged: (v) => setState(() => _published = v),
                      activeThumbColor: oc.success,
                      activeTrackColor: oc.success.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zones section
// ---------------------------------------------------------------------------

class _ZonesSection extends StatelessWidget {
  const _ZonesSection({
    required this.zones,
    required this.onRemove,
    required this.onEdit,
    required this.onAdd,
  });

  final List<ServiceZone> zones;
  final void Function(int index) onRemove;
  final void Function(int index) onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (zones.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.zoneNone,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ),
        for (var i = 0; i < zones.length; i++) ...[
          _ZoneChip(
            zone: zones[i],
            onTap: () => onEdit(i),
            onRemove: () => onRemove(i),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(l10n.zoneAdd),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: BorderSide(color: oc.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    required this.zone,
    required this.onTap,
    required this.onRemove,
  });

  final ServiceZone zone;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final radiusStr = zone.radiusKm > 0 ? '${zone.radiusKm} km' : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: oc.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: oc.border),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: oc.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (radiusStr != null)
                    Text(
                      l10n.zoneRadiusLabel(radiusStr),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              color: oc.secondaryText,
              tooltip: l10n.serviceFormPhotoRemove,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add zone bottom sheet
// ---------------------------------------------------------------------------

class _AddZoneSheet extends StatefulWidget {
  const _AddZoneSheet({required this.geocoding, this.existing});

  final GeocodingService geocoding;
  final ServiceZone? existing;

  @override
  State<_AddZoneSheet> createState() => _AddZoneSheetState();
}

class _AddZoneSheetState extends State<_AddZoneSheet> {
  late final TextEditingController _addressController;
  late double _radiusKm;
  bool _loading = false;
  String? _error;
  List<PlaceSuggestion> _suggestions = [];
  PlaceSuggestion? _selected;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _addressController = TextEditingController(text: e?.label ?? '');
    _radiusKm = e?.radiusKm.toDouble() ?? 30;
    // For editing, we already have coords - create a fake PlaceSuggestion
    // so _validate can reuse existing coords if the label hasn't changed.
    if (e != null) {
      _selected = PlaceSuggestion(placeId: '', description: e.label);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String input) async {
    if (input.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final results = await widget.geocoding.autocomplete(input);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {
      // Silently ignore - suggestions are not critical
    }
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    _selected = suggestion;
    _addressController.text = suggestion.description;
    setState(() {
      _suggestions = [];
      _error = null;
    });
  }

  Future<void> _validate() async {
    final l10n = AppLocalizations.of(context)!;
    final selectErrorMsg = l10n.zoneSelectError;
    final locateErrorMsg = l10n.zoneLocateError;
    final connectionErrorMsg = l10n.zoneConnectionError;

    if (_selected == null) {
      setState(() => _error = selectErrorMsg);
      return;
    }

    // Edit mode: if label unchanged, reuse existing coords (only radius changed)
    final e = widget.existing;
    if (e != null && _selected!.description == e.label) {
      Navigator.of(context).pop(
        ServiceZone(
          label: e.label,
          latitude: e.latitude,
          longitude: e.longitude,
          radiusKm: _radiusKm.round(),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.geocoding.getPlaceLatLng(_selected!.placeId);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _loading = false;
          _error = locateErrorMsg;
        });
        return;
      }

      Navigator.of(context).pop(
        ServiceZone(
          label: _selected!.description,
          latitude: result.lat,
          longitude: result.lng,
          radiusKm: _radiusKm.round(),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = connectionErrorMsg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: oc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _isEdit ? l10n.zoneSheetEditTitle : l10n.zoneSheetAddTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Address field with autocomplete
          TextFormField(
            controller: _addressController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.zoneCityOrAddress,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              errorText: _error,
            ),
            onChanged: (v) {
              _selected = null;
              _onSearchChanged(v);
            },
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
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: oc.border.withValues(alpha: 0.5)),
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return InkWell(
                    onTap: () => _selectSuggestion(s),
                    borderRadius: BorderRadius.circular(
                      i == 0 || i == _suggestions.length - 1 ? 12 : 0,
                    ),
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
                              style: Theme.of(context).textTheme.bodySmall,
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
          const SizedBox(height: 20),

          // Radius slider
          Text(l10n.zoneRadius, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _radiusKm,
                  min: 5,
                  max: 200,
                  divisions: 39,
                  activeColor: oc.primary,
                  inactiveColor: oc.border,
                  label: '${_radiusKm.round()} km',
                  onChanged: (v) => setState(() => _radiusKm = v),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${_radiusKm.round()} km',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: oc.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Validate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _validate,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? l10n.zoneEdit : l10n.zoneValidate),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo section
// ---------------------------------------------------------------------------

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photos,
    required this.uploading,
    required this.maxPhotos,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> photos;
  final bool uploading;
  final int maxPhotos;
  final VoidCallback onPick;
  final void Function(int index) onRemove;

  static const double _thumbSize = 104;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final canAddMore = photos.length < maxPhotos;

    // Empty state: full-width tappable placeholder so the first photo is easy
    // to add. Once photos exist, switch to a horizontal thumbnail strip.
    if (photos.isEmpty && !uploading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _AddPhotoTile(onTap: onPick, large: true),
        ),
      );
    }

    // Single-photo case (the standard now): show one large 16:9 preview with a
    // remove button, not a tiny thumbnail strip + counter (leftover multi UI).
    if (photos.length == 1 && maxPhotos == 1 && !uploading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _PhotoThumb(url: photos.first, onRemove: () => onRemove(0)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _thumbSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + ((canAddMore || uploading) ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i < photos.length) {
                return _PhotoThumb(
                  url: photos[i],
                  size: _thumbSize,
                  onRemove: () => onRemove(i),
                );
              }
              // Trailing add / uploading tile.
              return SizedBox(
                width: _thumbSize,
                height: _thumbSize,
                child: uploading
                    ? Container(
                        decoration: BoxDecoration(
                          color: oc.border,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _AddPhotoTile(onTap: onPick, large: false),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.serviceFormPhotoCount(photos.length, maxPhotos),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, this.size, required this.onRemove});

  final String url;
  // Fixed square thumbnail in the strip; null = fill the parent (large preview).
  final double? size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              headers: const {'Accept': '*/*'},
              frameBuilder: (_, child, frame, loaded) {
                if (loaded) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    if (frame == null)
                      ColoredBox(
                        color: oc.border,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                );
              },
              errorBuilder: (_, __, ___) => ColoredBox(
                color: oc.border,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: oc.icons,
                  size: 28,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: l10n.serviceFormPhotoRemove,
              child: Tooltip(
                message: l10n.serviceFormPhotoRemove,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap, required this.large});

  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: oc.cardSurface,
          border: Border.all(color: oc.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: large ? 36 : 28,
              color: oc.icons,
            ),
            if (large) ...[
              const SizedBox(height: 8),
              Text(
                l10n.serviceFormPhotoAdd,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form helpers
// ---------------------------------------------------------------------------

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.value,
    required this.selectable,
    required this.onChanged,
  });

  final CategoryId value;
  final List<CategoryId> selectable;
  final ValueChanged<CategoryId> onChanged;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Wrap(
      spacing: 8,
      children: selectable.map((c) {
        final selected = c == value;
        // Icon + label so the category reads visually, not by text alone.
        return ChoiceChip(
          avatar: Icon(
            c.icon,
            size: 18,
            color: selected ? oc.primary : oc.icons,
          ),
          label: Text(c.label),
          selected: selected,
          selectedColor: oc.primary.withValues(alpha: 0.12),
          labelStyle: TextStyle(
            color: selected ? oc.primary : oc.primaryText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          onSelected: (_) => onChanged(c),
        );
      }).toList(),
    );
  }
}

/// Billing-mode selector: hourly, daily, monthly (spec section 5, decision 4).
/// `fixed` is gone from the choices; a legacy fixed listing was mapped to daily
/// on load.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.value, required this.onChanged});

  final PriceType value;
  final ValueChanged<PriceType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<PriceType>(
      segments: [
        ButtonSegment(value: PriceType.hourly, label: Text(l10n.priceHourly)),
        ButtonSegment(value: PriceType.daily, label: Text(l10n.priceDaily)),
        ButtonSegment(value: PriceType.monthly, label: Text(l10n.priceMonthly)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
    );
  }
}

/// Extra-task checkboxes. Every option beyond the main category, capped at
/// [maxExtra]: once the cap is reached the unchecked boxes are disabled and a
/// text explains the limit, so the ceiling is never breached from the UI
/// (spec AC-04, SC-08) and the limit is not signalled by colour alone (A3).
class _ExtraTasksSelector extends StatelessWidget {
  const _ExtraTasksSelector({
    required this.options,
    required this.selected,
    required this.maxExtra,
    required this.limitLabel,
    required this.onToggle,
  });

  final List<CategoryId> options;
  final Set<String> selected;
  final int maxExtra;
  final String limitLabel;
  final void Function(String name, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final atLimit = selected.length >= maxExtra;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in options)
          _ExtraTaskTile(
            category: c,
            checked: selected.contains(c.name),
            // Keep already-checked tiles tappable so they can be unchecked;
            // only block adding beyond the cap.
            enabled: selected.contains(c.name) || !atLimit,
            onChanged: (v) => onToggle(c.name, v),
          ),
        if (atLimit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              limitLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ),
      ],
    );
  }
}

class _ExtraTaskTile extends StatelessWidget {
  const _ExtraTaskTile({
    required this.category,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final CategoryId category;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    // The whole row is the tap target (>= 44pt tall, A2), covering the label
    // and not just the box.
    return InkWell(
      onTap: enabled ? () => onChanged(!checked) : null,
      borderRadius: BorderRadius.circular(8),
      child: Semantics(
        label: category.label,
        checked: checked,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              ),
              Icon(
                category.icon,
                size: 18,
                color: enabled ? oc.icons : oc.icons.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: TextStyle(
                  color: enabled ? oc.primaryText : oc.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid still loading: a spinner in place of the pricing fields; publishing is
/// disabled by the parent (SC-12 case A).
class _PricingLoading extends StatelessWidget {
  const _PricingLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Grid unreadable (absent or failed): a plain-language message and a retry
/// action; no hard-coded fallback range (archi section 5, SC-12 cases B/C).
class _PricingError extends StatelessWidget {
  const _PricingError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: oc.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ),
        ],
      ),
    );
  }
}
