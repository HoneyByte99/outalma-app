import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';

// ---------------------------------------------------------------------------
// Country model + curated list (Francophone + major EU countries)
// ---------------------------------------------------------------------------

class _Country {
  const _Country({
    required this.flag,
    required this.name,
    required this.dialCode,
  });

  final String flag;
  final String name;
  final String dialCode;
}

const _kCountries = <_Country>[
  _Country(flag: '🇫🇷', name: 'France', dialCode: '+33'),
  _Country(flag: '🇸🇳', name: 'Sénégal', dialCode: '+221'),
  _Country(flag: '🇧🇪', name: 'Belgique', dialCode: '+32'),
  _Country(flag: '🇨🇭', name: 'Suisse', dialCode: '+41'),
  _Country(flag: '🇱🇺', name: 'Luxembourg', dialCode: '+352'),
  _Country(flag: '🇲🇦', name: 'Maroc', dialCode: '+212'),
  _Country(flag: '🇩🇿', name: 'Algérie', dialCode: '+213'),
  _Country(flag: '🇹🇳', name: 'Tunisie', dialCode: '+216'),
  _Country(flag: '🇨🇮', name: "Côte d'Ivoire", dialCode: '+225'),
  _Country(flag: '🇲🇱', name: 'Mali', dialCode: '+223'),
  _Country(flag: '🇬🇳', name: 'Guinée', dialCode: '+224'),
  _Country(flag: '🇧🇫', name: 'Burkina Faso', dialCode: '+226'),
  _Country(flag: '🇳🇪', name: 'Niger', dialCode: '+227'),
  _Country(flag: '🇹🇬', name: 'Togo', dialCode: '+228'),
  _Country(flag: '🇧🇯', name: 'Bénin', dialCode: '+229'),
  _Country(flag: '🇨🇲', name: 'Cameroun', dialCode: '+237'),
  _Country(flag: '🇬🇧', name: 'Royaume-Uni', dialCode: '+44'),
  _Country(flag: '🇩🇪', name: 'Allemagne', dialCode: '+49'),
  _Country(flag: '🇪🇸', name: 'Espagne', dialCode: '+34'),
  _Country(flag: '🇮🇹', name: 'Italie', dialCode: '+39'),
  _Country(flag: '🇵🇹', name: 'Portugal', dialCode: '+351'),
  _Country(flag: '🇺🇸', name: 'États-Unis', dialCode: '+1'),
  _Country(flag: '🇨🇦', name: 'Canada', dialCode: '+1'),
];

// Default to France
final _kDefaultCountry = _kCountries[0];

// ---------------------------------------------------------------------------
// PhoneField
//
// Displays [FLAG  +XX ▾ | local number]
// Calls onChanged with full E.164 (e.g. +33612345678) or null if empty.
// Pass initialValue as E.164 to pre-fill country + number.
// ---------------------------------------------------------------------------

class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late _Country _country;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _initFromValue(widget.initialValue);
    _ctrl.addListener(_notify);
  }

  void _initFromValue(String? value) {
    if (value == null || value.isEmpty) {
      _country = _kDefaultCountry;
      _ctrl = TextEditingController();
      return;
    }
    // Match longest dial-code first to avoid +1 swallowing +1XXX codes
    final sorted = [..._kCountries]
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    for (final c in sorted) {
      if (value.startsWith(c.dialCode)) {
        _country = c;
        _ctrl = TextEditingController(text: value.substring(c.dialCode.length));
        return;
      }
    }
    _country = _kDefaultCountry;
    _ctrl = TextEditingController(text: value.replaceFirst(RegExp(r'^\+\d+'), ''));
  }

  @override
  void dispose() {
    _ctrl.removeListener(_notify);
    _ctrl.dispose();
    super.dispose();
  }

  void _notify() {
    final local = _ctrl.text.trim();
    widget.onChanged(local.isEmpty ? null : '${_country.dialCode}$local');
  }

  void _pickCountry() async {
    final selected = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(selected: _country),
    );
    if (selected != null && selected != _country) {
      setState(() => _country = selected);
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;

    return Container(
      decoration: BoxDecoration(
        color: oc.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: oc.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Country picker chip ──────────────────────────────
          GestureDetector(
            onTap: _pickCountry,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_country.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    _country.dialCode,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: oc.primaryText,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: oc.icons,
                  ),
                ],
              ),
            ),
          ),

          // ── Divider ─────────────────────────────────────────
          Container(width: 1, height: 24, color: oc.border),

          // ── Number input ─────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.phone,
              textInputAction: widget.textInputAction,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
              ],
              onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
              decoration: InputDecoration(
                hintText: 'Numéro',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                hintStyle: TextStyle(color: oc.icons),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: oc.primaryText,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country picker bottom sheet
// ---------------------------------------------------------------------------

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});

  final _Country selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_Country> _filtered = _kCountries;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _kCountries
          : _kCountries
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.dialCode.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: oc.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: oc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Text(
                      'Indicatif pays',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 20,
                      color: oc.icons,
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un pays…',
                    prefixIcon: Icon(Icons.search_rounded, color: oc.icons, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Country list
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final c = _filtered[i];
                    final isSelected = c.dialCode == widget.selected.dialCode &&
                        c.name == widget.selected.name;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(c),
                      child: Container(
                        color: isSelected
                            ? oc.primary.withValues(alpha: 0.07)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Text(c.flag, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                c.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? oc.primary
                                          : oc.primaryText,
                                    ),
                              ),
                            ),
                            Text(
                              c.dialCode,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isSelected
                                        ? oc.primary
                                        : oc.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_rounded,
                                  color: oc.primary, size: 18),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: bottomPadding),
            ],
          ),
        );
      },
    );
  }
}
