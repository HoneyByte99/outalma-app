import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/service/service_providers.dart';
import '../../domain/enums/category_id.dart';
import '../../domain/enums/price_type.dart';
import '../../domain/models/service.dart';

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
  late final TextEditingController _zoneController;
  late CategoryId _category;
  late PriceType _priceType;
  late bool _published;
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
    _zoneController = TextEditingController(text: s?.serviceArea ?? '');
    _category = s?.categoryId ?? CategoryId.menage;
    _priceType = s?.priceType ?? PriceType.hourly;
    _published = s?.published ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _zoneController.dispose();
    super.dispose();
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
          serviceArea: _zoneController.text.trim().isEmpty
              ? null
              : _zoneController.text.trim(),
          published: _published,
          updatedAt: DateTime.now(),
        );
        await repo.update(updated);
      } else {
        final now = DateTime.now();
        final service = Service(
          id: '',
          providerId: authState.user.id,
          categoryId: _category,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          photos: const [],
          priceType: _priceType,
          price: priceEuros * 100,
          published: _published,
          serviceArea: _zoneController.text.trim().isEmpty
              ? null
              : _zoneController.text.trim(),
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

              // Zone
              const _Label('Zone d\'intervention (optionnel)'),
              TextFormField(
                controller: _zoneController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Paris 75, Île-de-France',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
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

  static const _labels = {
    CategoryId.menage: 'Ménage',
    CategoryId.plomberie: 'Plomberie',
    CategoryId.jardinage: 'Jardinage',
    CategoryId.autre: 'Autre',
  };

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
