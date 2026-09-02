import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../domain/avatars/avatar_catalog.dart';
import '../shared/user_avatar.dart';

/// What the sheet hands back. The three outcomes are mutually exclusive, which
/// is why one type carries them instead of three booleans.
sealed class AvatarPick {
  const AvatarPick();
}

/// Open the gallery and import a photo.
class PickPhoto extends AvatarPick {
  const PickPhoto();
}

/// Use this catalogue avatar.
class PickAvatar extends AvatarPick {
  const PickAvatar(this.avatarId);
  final String avatarId;
}

/// Use neither, go back to initials.
class PickNone extends AvatarPick {
  const PickNone();
}

/// Opens the picker and returns the choice, or null if it was dismissed.
Future<AvatarPick?> showAvatarPickerSheet(
  BuildContext context, {
  required String? currentAvatarId,
  required bool hasPhoto,
}) {
  return showModalBottomSheet<AvatarPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        AvatarPickerSheet(currentAvatarId: currentAvatarId, hasPhoto: hasPhoto),
  );
}

/// The avatar picker: import a photo, pick an illustration, or pick neither.
///
/// U1 does not apply here and that is deliberate rather than an omission: the
/// sheet loads no data, every asset is local, so loading, empty and error
/// states have no meaning. The only failure path is the WRITE that follows a
/// choice, and it is handled by the caller, which already owns a spinner and a
/// snackbar.
class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({
    super.key,
    required this.currentAvatarId,
    required this.hasPhoto,
  });

  /// The avatar the person is using right now, so the grid opens on it AND on
  /// its skin tone. Without it, somebody using tone 5 who opens the sheet and
  /// taps another character would be silently moved back to the default tone.
  final String? currentAvatarId;

  /// Whether a real photo is on file, which decides if "remove" is offered.
  final bool hasPhoto;

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late int _tone;

  @override
  void initState() {
    super.initState();
    _tone =
        AvatarCatalog.parse(widget.currentAvatarId)?.toneIndex ??
        AvatarCatalog.defaultToneIndex;
  }

  String? get _currentCharacter {
    final id = widget.currentAvatarId;
    if (id == null) return null;
    final match = RegExp(r'_t[1-6]$').firstMatch(id);
    return match == null ? id : id.substring(0, match.start);
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    final hasSomething = widget.hasPhoto || widget.currentAvatarId != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: oc.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXLarge),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: oc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.avatarSheetTitle,
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
                      tooltip: l10n.avatarSheetClose,
                    ),
                  ],
                ),
              ),

              _SheetAction(
                icon: Icons.photo_library_rounded,
                label: l10n.avatarImportPhoto,
                onTap: () => Navigator.of(context).pop(const PickPhoto()),
              ),
              if (hasSomething)
                _SheetAction(
                  icon: Icons.person_outline_rounded,
                  label: l10n.avatarRemove,
                  onTap: () => Navigator.of(context).pop(const PickNone()),
                ),
              const Divider(height: 1),

              // Above the grid so it is reachable without scrolling: changing
              // the tone is meant to be one gesture.
              _ToneRow(
                selected: _tone,
                onSelected: (i) => setState(() => _tone = i),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.m,
                    AppSpacing.l,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _AvatarGrid(
                      ids: AvatarCatalog.humanIds,
                      tone: _tone,
                      currentCharacter: _currentCharacter,
                      labelBuilder: (i) =>
                          l10n.avatarItemLabel(i + 1, AvatarCatalog.humanCount),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.avatarSectionAnimals,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _AvatarGrid(
                      ids: AvatarCatalog.animalIds,
                      tone: _tone,
                      currentCharacter: _currentCharacter,
                      labelBuilder: (i) => l10n.avatarAnimalLabel(
                        i + 1,
                        AvatarCatalog.animalCount,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A full-width row action, sized to the minimum touch target (A2).
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: oc.primary),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: oc.icons),
          ],
        ),
      ),
    );
  }
}

/// The six skin-tone swatches.
class _ToneRow extends StatelessWidget {
  const _ToneRow({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.avatarSkinToneLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              for (var i = 0; i < AvatarCatalog.skinTones.length; i++)
                Semantics(
                  button: true,
                  selected: i == selected,
                  label: l10n.avatarSkinToneItem(
                    i + 1,
                    AvatarCatalog.skinTones.length,
                  ),
                  child: InkShape(
                    onTap: () => onSelected(i),
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(AvatarCatalog.skinTones[i]),
                          shape: BoxShape.circle,
                          // The swatch IS the control, and the two lightest
                          // tones measure 1.65:1 and 2.04:1 against the white
                          // sheet: without a border they disappear.
                          border: Border.all(color: oc.border),
                        ),
                        // A3: selection never rests on colour alone. The check
                        // colour switches at index 3 because no single colour
                        // clears 4.5:1 on all six tones.
                        child: i == selected
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Color(AvatarCatalog.toneCheckColors[i]),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 44x44 tap target wrapping a smaller visual, so A2 holds without making
/// the swatch itself huge.
class InkShape extends StatelessWidget {
  const InkShape({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: AppSpacing.minTouchTarget,
        height: AppSpacing.minTouchTarget,
        child: child,
      ),
    );
  }
}

/// A grid of catalogue tiles. Each tile is a [UserAvatar], so there is exactly
/// one SVG rendering path in the app and the picker shares its image cache
/// with the 14 display sites.
class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.ids,
    required this.tone,
    required this.currentCharacter,
    required this.labelBuilder,
  });

  final List<String> ids;
  final int tone;
  final String? currentCharacter;
  final String Function(int index) labelBuilder;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.m,
        childAspectRatio: 1,
      ),
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final characterId = ids[index];
        final isSelected = characterId == currentCharacter;
        final id = AvatarCatalog.composeId(characterId, tone);

        return Semantics(
          button: true,
          selected: isSelected,
          label: labelBuilder(index),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(PickAvatar(id)),
            customBorder: const CircleBorder(),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? oc.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: LayoutBuilder(
                      builder: (context, constraints) => UserAvatar(
                        // Keyed on the composed id so a tone change actually
                        // rebuilds the tile.
                        key: ValueKey(id),
                        displayName: '',
                        avatarId: id,
                        radius: constraints.maxWidth / 2,
                      ),
                    ),
                  ),
                ),
                // A3 again: the ring alone would say "selected" by colour.
                if (isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: oc.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: oc.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
