import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            content: const Text('Impossible d\'importer la photo. Réessayez.'),
            backgroundColor: context.oc.error,
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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
            content: const Text('Impossible d\'enregistrer. Réessayez.'),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le service' : 'Nouveau service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Enregistrer'),
            ),
        ],
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
              const _Label('Titre du service'),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ex: Nettoyage complet d\'appartement',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
              ),
              const SizedBox(height: 20),

              // Category
              const _Label('Catégorie'),
              _CategorySelector(
                value: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 20),

              // Description
              const _Label('Description (optionnel)'),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Décrivez ce que vous proposez...',
                ),
              ),
              const SizedBox(height: 20),

              // Price + type
              const _Label('Tarif'),
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
                          return 'Requis';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Invalide';
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
              const _Label('Zones d\'intervention'),
              _ZonesSection(
                zones: _zones,
                onRemove: _removeZone,
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
                            'Publier ce service',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Visible par les clients',
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
    required this.onAdd,
  });

  final List<ServiceZone> zones;
  final void Function(int index) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (zones.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Aucune zone ajoutée',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: oc.secondaryText),
            ),
          ),
        for (var i = 0; i < zones.length; i++) ...[
          _ZoneChip(zone: zones[i], onRemove: () => onRemove(i)),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Ajouter une zone'),
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
  const _ZoneChip({required this.zone, required this.onRemove});

  final ServiceZone zone;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final subtitle = zone.radiusKm > 0 ? '${zone.radiusKm} km' : null;
    return Container(
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
                if (subtitle != null)
                  Text(
                    'Rayon : $subtitle',
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
    );
  }
}

// ---------------------------------------------------------------------------
// Add zone bottom sheet
// ---------------------------------------------------------------------------

class _AddZoneSheet extends StatefulWidget {
  const _AddZoneSheet({required this.geocoding});

  final GeocodingService geocoding;

  @override
  State<_AddZoneSheet> createState() => _AddZoneSheetState();
}

class _AddZoneSheetState extends State<_AddZoneSheet> {
  final _addressController = TextEditingController();
  double _radiusKm = 30;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Saisissez une adresse ou une ville');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.geocoding.geocode(address);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Adresse introuvable. Vérifiez et réessayez.';
        });
        return;
      }

      Navigator.of(context).pop(ServiceZone(
        label: address,
        latitude: result.lat,
        longitude: result.lng,
        radiusKm: _radiusKm.round(),
      ));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Connexion requise pour ajouter une zone.';
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
            'Ajouter une zone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Address field
          TextFormField(
            controller: _addressController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Adresse ou ville',
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 20),
              errorText: _error,
            ),
            onFieldSubmitted: (_) => _validate(),
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
                  : const Text('Valider'),
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
      return Container(
        color: context.oc.border,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (photos.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photos.first,
            fit: BoxFit.cover,
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
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return _Placeholder(onTap: onPick);
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
        width: double.infinity,
        height: double.infinity,
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
    return DropdownButtonFormField<PriceType>(
      initialValue: value,
      decoration: const InputDecoration(),
      items: const [
        DropdownMenuItem(
          value: PriceType.hourly,
          child: Text('par heure'),
        ),
        DropdownMenuItem(
          value: PriceType.fixed,
          child: Text('forfait'),
        ),
      ],
      onChanged: (t) {
        if (t != null) onChanged(t);
      },
    );
  }
}
