import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../domain/auth/phone_number.dart';
import '../../domain/utils/text_search.dart';
import 'app_sheet.dart';

// ---------------------------------------------------------------------------
// Country model + curated list (Francophone + major EU countries)
// ---------------------------------------------------------------------------

/// The selector's countries, in display order. The name is localised
/// (budget line U4), and the switch in [name] is exhaustive: a country added
/// here without its entry in the template (app_en.arb) does not compile, and
/// test/l10n/arb_parity_test.dart catches a missing French one.
enum _Country {
  france('🇫🇷', '+33'),
  senegal('🇸🇳', '+221'),
  belgium('🇧🇪', '+32'),
  switzerland('🇨🇭', '+41'),
  luxembourg('🇱🇺', '+352'),
  morocco('🇲🇦', '+212'),
  algeria('🇩🇿', '+213'),
  tunisia('🇹🇳', '+216'),
  ivoryCoast('🇨🇮', '+225'),
  mali('🇲🇱', '+223'),
  guinea('🇬🇳', '+224'),
  burkinaFaso('🇧🇫', '+226'),
  niger('🇳🇪', '+227'),
  togo('🇹🇬', '+228'),
  benin('🇧🇯', '+229'),
  cameroon('🇨🇲', '+237'),
  unitedKingdom('🇬🇧', '+44'),
  germany('🇩🇪', '+49'),
  spain('🇪🇸', '+34'),
  italy('🇮🇹', '+39'),
  portugal('🇵🇹', '+351'),
  unitedStates('🇺🇸', '+1'),
  canada('🇨🇦', '+1');

  const _Country(this.flag, this.dialCode);

  final String flag;
  final String dialCode;

  String name(AppLocalizations l10n) => switch (this) {
    _Country.france => l10n.countryNameFR,
    _Country.senegal => l10n.countryNameSN,
    _Country.belgium => l10n.countryNameBE,
    _Country.switzerland => l10n.countryNameCH,
    _Country.luxembourg => l10n.countryNameLU,
    _Country.morocco => l10n.countryNameMA,
    _Country.algeria => l10n.countryNameDZ,
    _Country.tunisia => l10n.countryNameTN,
    _Country.ivoryCoast => l10n.countryNameCI,
    _Country.mali => l10n.countryNameML,
    _Country.guinea => l10n.countryNameGN,
    _Country.burkinaFaso => l10n.countryNameBF,
    _Country.niger => l10n.countryNameNE,
    _Country.togo => l10n.countryNameTG,
    _Country.benin => l10n.countryNameBJ,
    _Country.cameroon => l10n.countryNameCM,
    _Country.unitedKingdom => l10n.countryNameGB,
    _Country.germany => l10n.countryNameDE,
    _Country.spain => l10n.countryNameES,
    _Country.italy => l10n.countryNameIT,
    _Country.portugal => l10n.countryNamePT,
    _Country.unitedStates => l10n.countryNameUS,
    _Country.canada => l10n.countryNameCA,
  };
}

const _kCountries = _Country.values;

// Default to France
const _kDefaultCountry = _Country.france;

// ---------------------------------------------------------------------------
// PhoneField
//
// Displays [FLAG  +XX ▾ | local number]
// Calls onChanged with the canonical E.164 (composeE164: "06 12 34 56 78"
// with France gives +33612345678), or null if no digit was typed.
// Pass initialValue as E.164 to pre-fill country + number.
// ---------------------------------------------------------------------------

/// Minimum number of local digits (excluding dial code) to consider valid.
const _kMinLocalDigits = 7;

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

  /// The dial codes this product offers, derived from the selector's own list
  /// so the two cannot drift.
  ///
  /// Public because the server guard carries the same allowlist
  /// (`ALLOWED_PREFIXES` in `functions/src/otp_rate_limit.ts`), and the two are
  /// held together by a parity test on each side
  /// (`test/shared/phone_prefix_parity_test.dart` here,
  /// `functions/test/otp_rate_limit.test.ts` there), both reading
  /// `shared/allowed-phone-prefixes.json`. A code offered here but missing
  /// there is a user who picks their country and is refused for picking it.
  ///
  /// A Set, not a List: +1 appears twice in the selector (the United States and
  /// Canada share the NANP), and the allowlist is about codes, not countries.
  static final Set<String> supportedDialCodes = {
    for (final c in _kCountries) c.dialCode,
  };

  /// Returns `null` when [value] (E.164 string) is valid, or an error message
  /// in the language of [l10n].
  static String? validate(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return null; // optional field
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    // E.164 total length: country code (1-3) + local (typically 7-12)
    if (digitsOnly.length < _kMinLocalDigits) {
      return l10n.phoneFieldTooShort;
    }
    if (digitsOnly.length > 15) {
      return l10n.phoneFieldTooLong;
    }
    return null;
  }

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late _Country _country;
  late TextEditingController _ctrl;
  String? _error;

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
    _ctrl = TextEditingController(
      text: value.replaceFirst(RegExp(r'^\+\d+'), ''),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_notify);
    _ctrl.dispose();
    super.dispose();
  }

  void _notify() {
    // The canonical string, not the text as typed: "06 39 98 12 34" goes out
    // as +33639981234. The field itself keeps showing what the user typed.
    final e164 = composeE164(_country.dialCode, _ctrl.text);
    final err = PhoneField.validate(AppLocalizations.of(context)!, e164);
    setState(() => _error = err);
    widget.onChanged(e164);
  }

  void _pickCountry() async {
    final selected = await showAppSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      maxHeightFraction: sheetFractionCompact,
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

    final hasError = _error != null && _ctrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: oc.inputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hasError ? oc.error : oc.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Country picker chip ──────────────────────────────
              GestureDetector(
                onTap: _pickCountry,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
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
                  // The dial code lives in the selector beside this field
                  // (see initState, which strips it from the controller
                  // text), so the hint is the national number, not the
                  // full E.164 telephoneNumber.
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
                  ],
                  onSubmitted: widget.onSubmitted != null
                      ? (_) => widget.onSubmitted!()
                      : null,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.phoneFieldHint,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: oc.primaryText),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.error),
            ),
          ),
      ],
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
    // Folded on BOTH sides: the country list carries accents ("Sénégal"), and
    // someone signing up on a phone in Dakar types "senegal". Folding only the
    // name would leave the mirror case broken.
    final l10n = AppLocalizations.of(context)!;
    final q = foldForSearch(_searchCtrl.text);
    setState(() {
      _filtered = q.isEmpty
          ? _kCountries
          : _kCountries
                .where(
                  (c) =>
                      foldForSearch(c.name(l10n)).contains(q) ||
                      c.dialCode.contains(q),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Handle and title stay OUTSIDE the scroll view so the sheet keeps its
    // drag-to-close gesture there; the field and the list scroll together,
    // which is what lets the wrapper (showAppSheet) keep them above the
    // keyboard. The search field takes focus on open, so the keyboard is up
    // from the first frame.
    return Container(
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  l10n.countryPickerTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.sheetClose,
                  iconSize: 20,
                  color: oc.icons,
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.countryPickerSearchHint,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: oc.icons,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Country list. A ListView (not a Column) so tests keep
                  // finding rows under it; non-scrollable because the outer
                  // scroll view owns the gesture.
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) =>
                        _countryRow(context, _filtered[i], oc),
                  ),

                  SizedBox(height: bottomPadding),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countryRow(BuildContext context, _Country c, OutalmaColors oc) {
    final isSelected = c == widget.selected;
    return InkWell(
      onTap: () => Navigator.of(context).pop(c),
      child: Container(
        color: isSelected ? oc.primary.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(c.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                c.name(AppLocalizations.of(context)!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? oc.primary : oc.primaryText,
                ),
              ),
            ),
            Text(
              c.dialCode,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected ? oc.primary : oc.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, color: oc.primary, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
