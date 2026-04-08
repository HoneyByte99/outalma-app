import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/service/service_providers.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/service_photo_upload_service.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/price_type.dart';
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
  late final TextEditingController _priceController;
  late CategoryId _category;
  late PriceType _priceType;
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
    _descriptionController =
        TextEditingController(text: s?.description ?? '');
    _priceController = TextEditingController(
      text: s != null ? (s.price / 100).toStringAsFixed(0) : '',
    );
    _category = s?.categoryId ?? CategoryId.menage;
    _priceType = s?.priceType ?? PriceType.hourly;
    _published = s?.published ?? false;
    _photos = List<String>.from(s?.photos ?? []);
    _zones = List<ServiceZone>.from(s?.serviceZones ?? []);
    _pendingServiceId = _isEdit
        ? widget.existing!.id
        : FirebaseFirestore.instance.collection('services').doc().id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final photoErrorMsg = l10n.serviceFormPhotoError;
    final errorColor = context.oc.error;
    final uploader = ref.read(servicePhotoUploadServiceProvider);
    setState(() => _uploadingPhoto = true);
    try {
      final url = await uploader.pickAndUpload(_pendingServiceId);
      if (url != null && mounted) {
        setState(() => _photos = [url]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(photoErrorMsg),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _removePhoto() {
    setState(() => _photos = []);
  }

  void _removeZone(int index) {
    setState(() => _zones = [..._zones]..removeAt(index));
  }

  Future<void> _showAddZoneSheet() async {
    final zone = await showModalBottomSheet<ServiceZone>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddZoneSheet(geocoding: ref.read(geocodingServiceProvider)),
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
        SnackBar(
          content: Text(zonesRequiredMsg),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final priceEuros = int.tryParse(_priceController.text.trim()) ?? 0;

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
          price: priceEuros * 100,
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
          price: priceEuros * 100,
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
          SnackBar(
            content: Text(saveErrorMsg),
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
        title: Text(_isEdit ? l10n.serviceFormEditTitle : l10n.serviceFormCreateTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.serviceFormTitleRequired : null,
              ),
              const SizedBox(height: 20),

              // Category
              _Label(l10n.serviceFormCategory),
              _CategorySelector(
                value: _category,
                onChanged: (c) => setState(() => _category = c),
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

              // Price + type
              _Label(l10n.serviceFormPrice),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        hintText: '0',
                        suffixText: '€',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.serviceFormPriceRequired;
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return l10n.serviceFormPriceInvalid;
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _PriceTypeSelector(
                      value: _priceType,
                      onChanged: (t) => setState(() => _priceType = t),
                    ),
                  ),
                ],
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: oc.surface,
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.serviceFormPublishSubtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: oc.secondaryText,
                                ),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: oc.secondaryText),
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
        color: oc.surface,
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: oc.secondaryText),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 18, color: oc.secondaryText),
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
    // For editing, we already have coords — create a fake PlaceSuggestion
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
      // Silently ignore — suggestions are not critical
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
      Navigator.of(context).pop(ServiceZone(
        label: e.label,
        latitude: e.latitude,
        longitude: e.longitude,
        radiusKm: _radiusKm.round(),
      ));
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

      Navigator.of(context).pop(ServiceZone(
        label: _selected!.description,
        latitude: result.lat,
        longitude: result.lng,
        radiusKm: _radiusKm.round(),
      ));
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
            _isEdit ? 'Modifier la zone' : 'Ajouter une zone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Address field with autocomplete
          TextFormField(
            controller: _addressController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ville ou adresse',
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
                color: oc.surface,
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
                          Icon(Icons.location_on_outlined,
                              size: 16, color: oc.secondaryText),
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
          Text(
            'Rayon d\'intervention',
            style: Theme.of(context).textTheme.titleSmall,
          ),
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
                  : Text(_isEdit ? 'Modifier' : 'Valider'),
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
    required this.onPick,
    required this.onRemove,
  });

  final List<String> photos;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildContent(context, oc),
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic oc) {
    if (uploading) {
      return SizedBox.expand(
        child: ColoredBox(
          color: context.oc.border,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (photos.isNotEmpty) {
      return SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photos.first,
              fit: BoxFit.cover,
              frameBuilder: (_, child, frame, loaded) {
                if (loaded) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    if (frame == null)
                      ColoredBox(
                        color: context.oc.border,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                );
              },
              errorBuilder: (_, __, ___) => _Placeholder(onTap: onPick),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(child: _Placeholder(onTap: onPick));
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: oc.surface,
          border: Border.all(
            color: oc.border,
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 36,
              color: oc.icons,
            ),
            const SizedBox(height: 8),
            Text(
              'Ajouter une photo (optionnel)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.secondaryText,
                  ),
            ),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.value, required this.onChanged});

  final CategoryId value;
  final ValueChanged<CategoryId> onChanged;

  static Map<CategoryId, String> get _labels =>
      {for (final c in CategoryId.values) c: c.label};

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Wrap(
      spacing: 8,
      children: CategoryId.values.map((c) {
        final selected = c == value;
        return ChoiceChip(
          label: Text(_labels[c]!),
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

class _PriceTypeSelector extends StatelessWidget {
  const _PriceTypeSelector({required this.value, required this.onChanged});

  final PriceType value;
  final ValueChanged<PriceType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DropdownButtonFormField<PriceType>(
      initialValue: value,
      decoration: const InputDecoration(),
      items: [
        DropdownMenuItem(
          value: PriceType.hourly,
          child: Text(l10n.priceHourly),
        ),
        DropdownMenuItem(
          value: PriceType.fixed,
          child: Text(l10n.priceFixed),
        ),
      ],
      onChanged: (t) {
        if (t != null) onChanged(t);
      },
    );
  }
}
