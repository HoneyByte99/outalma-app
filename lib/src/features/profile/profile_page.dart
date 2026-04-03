import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/review/review_providers.dart';
import '../../application/theme/theme_provider.dart';
import '../../application/user/user_providers.dart';
import '../../data/services/avatar_upload_service.dart';
import '../../domain/enums/active_mode.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/review.dart';
import '../shared/user_avatar.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final authAsync = ref.watch(authNotifierProvider);
    final user = authAsync.valueOrNull is AuthAuthenticated
        ? (authAsync.valueOrNull as AuthAuthenticated).user
        : null;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: const Text('Profil & Paramètres'),
        backgroundColor: oc.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EditableUserHeader(),
            const SizedBox(height: 28),
            if (user != null) ...[
              const _SectionLabel(label: 'Mes avis'),
              const SizedBox(height: 12),
              _MyReviewsSection(uid: user.id),
              const SizedBox(height: 28),
            ],
            const _SectionLabel(label: 'Mode actif'),
            const SizedBox(height: 12),
            const _ModeToggle(),
            const SizedBox(height: 28),
            if (user != null) ...[
              const _SectionLabel(label: 'Informations'),
              const SizedBox(height: 12),
              _ProfileForm(user: user),
              const SizedBox(height: 28),
            ],
            const _SectionLabel(label: 'Apparence'),
            const SizedBox(height: 12),
            const _ThemeSelector(),
            const SizedBox(height: 28),
            const _SectionLabel(label: 'Compte'),
            const SizedBox(height: 12),
            _AccountSection(user: user),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editable user header (avatar tap-to-change)
// ---------------------------------------------------------------------------

class _EditableUserHeader extends ConsumerStatefulWidget {
  const _EditableUserHeader();

  @override
  ConsumerState<_EditableUserHeader> createState() =>
      _EditableUserHeaderState();
}

class _EditableUserHeaderState extends ConsumerState<_EditableUserHeader> {
  bool _uploading = false;

  Future<void> _pickAvatar() async {
    // Read current user at call time — don't depend on widget prop
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final service = ref.read(avatarUploadServiceProvider);
    if (service == null) return;

    setState(() => _uploading = true);
    try {
      final url = await service.pickAndUpload();
      if (url == null) return; // user cancelled

      await ref.read(authNotifierProvider.notifier).updateProfile(
            displayName: authState.user.displayName,
            photoPath: url,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: context.oc.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    // Watch directly — always fresh, no prop-timing race condition
    final authAsync = ref.watch(authNotifierProvider);
    final user = authAsync.valueOrNull is AuthAuthenticated
        ? (authAsync.valueOrNull as AuthAuthenticated).user
        : null;

    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: oc.border),
      ),
      child: Row(
        children: [
          // Tappable avatar with camera overlay
          GestureDetector(
            onTap: _uploading ? null : _pickAvatar,
            child: Stack(
              children: [
                _uploading
                    ? SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: oc.primary,
                        ),
                      )
                    : UserAvatar(
                        key: ValueKey(user.photoPath),
                        displayName: user.displayName,
                        photoPath: user.photoPath,
                        radius: 30,
                      ),
                if (!_uploading)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: oc.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: oc.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: oc.secondaryText,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.country.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: oc.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      user.country.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: oc.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile edit form
// ---------------------------------------------------------------------------

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late String _country;
  bool _saving = false;

  static const _countries = [
    ('FR', 'France'),
    ('SN', 'Sénégal'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _phoneCtrl = TextEditingController(text: widget.user.phoneE164 ?? '');
    _country = widget.user.country;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
            displayName: _nameCtrl.text.trim(),
            phoneE164:
                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            country: _country,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de sauvegarder. Réessayez.'),
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
    return Container(
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: oc.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email — read-only
            _ReadOnlyField(
              label: 'Email',
              value: widget.user.email,
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 14),

            // Display name
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                context,
                label: 'Nom complet',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 14),

            // Phone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                context,
                label: 'Téléphone (optionnel)',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 14),

            // Country picker
            _CountryPicker(
              selected: _country,
              countries: _countries,
              onChanged: (v) => setState(() => _country = v),
            ),
            const SizedBox(height: 20),

            // Save button
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: oc.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: oc.secondaryText,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: oc.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: oc.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: oc.icons),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: oc.secondaryText,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountryPicker extends StatelessWidget {
  const _CountryPicker({
    required this.selected,
    required this.countries,
    required this.onChanged,
  });

  final String selected;
  final List<(String, String)> countries;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pays',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: oc.secondaryText,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: countries.map((entry) {
            final (code, label) = entry;
            final isSelected = code == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: code == countries.last.$1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () => onChanged(code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? oc.primary.withValues(alpha: 0.08)
                          : oc.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? oc.primary : oc.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isSelected ? oc.primary : oc.primaryText,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
}) {
  final oc = context.oc;
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: oc.icons),
    filled: true,
    fillColor: oc.inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: oc.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: oc.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: oc.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: oc.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: oc.error, width: 1.5),
    ),
  );
}

// ---------------------------------------------------------------------------
// Mode toggle
// ---------------------------------------------------------------------------

class _ModeToggle extends ConsumerStatefulWidget {
  const _ModeToggle();

  @override
  ConsumerState<_ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends ConsumerState<_ModeToggle> {
  bool _saving = false;

  Future<void> _select(ActiveMode mode) async {
    if (ref.read(activeModeProvider) == mode) return;
    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).switchMode(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible de changer de mode. Réessayez.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final activeMode = ref.watch(activeModeProvider);

    if (_saving) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: oc.primary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ModeTile(
            icon: Icons.search_rounded,
            label: 'Client',
            subtitle: 'Réserver des services',
            isActive: activeMode == ActiveMode.client,
            color: oc.primary,
            onTap: () => _select(ActiveMode.client),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeTile(
            icon: Icons.handyman_rounded,
            label: 'Prestataire',
            subtitle: 'Gérer mes missions',
            isActive: activeMode == ActiveMode.provider,
            color: oc.success,
            onTap: () => _select(ActiveMode.provider),
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.08) : oc.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color : oc.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isActive ? color : oc.icons, size: 22),
                if (isActive)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive ? color : oc.primaryText,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.secondaryText,
                    height: 1.3,
                  ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme selector
// ---------------------------------------------------------------------------

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final current = ref.watch(themeModeProvider);

    final options = [
      (ThemeMode.system, Icons.brightness_auto_outlined, 'Système'),
      (ThemeMode.light, Icons.light_mode_outlined, 'Clair'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Sombre'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        children: options.asMap().entries.map((entry) {
          final i = entry.key;
          final (mode, icon, label) = entry.value;
          final isSelected = current == mode;

          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(14) : Radius.zero,
                  bottom: i == options.length - 1
                      ? const Radius.circular(14)
                      : Radius.zero,
                ),
                onTap: () =>
                    ref.read(themeModeProvider.notifier).setThemeMode(mode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected ? oc.primary : oc.icons,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: isSelected
                                    ? oc.primary
                                    : oc.primaryText,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded,
                            color: oc.primary, size: 18),
                    ],
                  ),
                ),
              ),
              if (i < options.length - 1)
                Divider(
                    height: 1, indent: 50, color: oc.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account section
// ---------------------------------------------------------------------------

class _AccountSection extends ConsumerWidget {
  const _AccountSection({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;

    return Container(
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: oc.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 20, color: oc.error),
              const SizedBox(width: 14),
              Text(
                'Se déconnecter',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: oc.error,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My reviews section
// ---------------------------------------------------------------------------

class _MyReviewsSection extends ConsumerWidget {
  const _MyReviewsSection({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final reviewsAsync = ref.watch(reviewsForUserProvider(uid));

    return reviewsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: oc.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: oc.border),
            ),
            child: Row(
              children: [
                Icon(Icons.star_outline_rounded, size: 20, color: oc.icons),
                const SizedBox(width: 12),
                Text(
                  'Aucun avis reçu pour le moment',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: oc.secondaryText),
                ),
              ],
            ),
          );
        }

        final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            reviews.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: oc.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: oc.border),
              ),
              child: Row(
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: oc.primaryText,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < avg.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: const Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reviews.length} avis',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: oc.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Review tiles
            ...reviews.map((r) => _ReviewTile(review: r)),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final reviewer =
        ref.watch(userByIdProvider(review.reviewerId)).valueOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                displayName: reviewer?.displayName ?? '',
                photoPath: reviewer?.photoPath,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reviewer?.displayName ?? '—',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.secondaryText,
                    height: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.oc.secondaryText,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
    );
  }
}
