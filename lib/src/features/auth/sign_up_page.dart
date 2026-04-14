import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_notifier.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/theme/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../shared/phone_field.dart';

// ---------------------------------------------------------------------------
// Auth mode enum
// ---------------------------------------------------------------------------

enum _AuthMode { mail, phone }

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  _AuthMode _mode = _AuthMode.mail;

  // Shared
  final _nameController = TextEditingController();

  // Email fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Phone fields
  String? _phoneE164;

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Email sign-up
  // ---------------------------------------------------------------------------

  Future<void> _signUpEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError(l10n.signUpErrorEmptyFields);
      return;
    }
    if (password.length < 6) {
      _showError(l10n.signUpErrorPasswordTooShort);
      return;
    }

    final errorGeneral = l10n.errorGeneral;
    setState(() => _loading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await ref.read(authNotifierProvider.notifier).createUserDoc(
            uid: credential.user!.uid,
            displayName: name,
            email: email,
          );
    } on PhoneTakenException {
      _showError(l10n.authErrorPhoneTaken);
    } on FirebaseAuthException catch (e) {
      _showError(_mapFirebaseError(e.code));
    } catch (_) {
      _showError(errorGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Phone sign-up (no OTP for now — uses temp email auth under the hood)
  // ---------------------------------------------------------------------------

  Future<void> _signUpPhone() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final phone = _phoneE164;

    if (name.isEmpty) {
      _showError(l10n.signUpErrorEmptyFields);
      return;
    }
    if (phone == null || phone.isEmpty) {
      _showError(l10n.signUpErrorEmptyFields);
      return;
    }

    final phoneError = PhoneField.validate(phone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    final errorGeneral = l10n.errorGeneral;
    setState(() => _loading = true);

    try {
      await ref.read(authNotifierProvider.notifier).signUpWithPhone(
            phoneE164: phone,
            displayName: name,
          );
    } on PhoneTakenException {
      _showError(l10n.authErrorPhoneTaken);
    } on FirebaseAuthException catch (e) {
      _showError(_mapFirebaseError(e.code));
    } catch (_) {
      _showError(errorGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _mapFirebaseError(String code) {
    final l10n = AppLocalizations.of(context)!;
    return switch (code) {
      'email-already-in-use' => l10n.authErrorEmailAlreadyInUse,
      'invalid-email' => l10n.authErrorInvalidEmail,
      'weak-password' => l10n.authErrorWeakPassword,
      _ => l10n.authErrorSignUpFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: oc.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: const [_ThemeToggleButton(), SizedBox(width: 8)],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ---- Logo ----
                _AuthLogo(),
                const SizedBox(height: 32),

                // ---- Heading ----
                Text(
                  l10n.signUpTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.signUpSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: oc.secondaryText,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ---- Mail / Phone toggle ----
                _AuthModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 28),

                // ---- Name (shared between both modes) ----
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.signUpNameHint,
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Mode-specific fields ----
                if (_mode == _AuthMode.mail) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: l10n.signInEmailHint,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signUpEmail(),
                    decoration: InputDecoration(
                      hintText: l10n.signUpPasswordHint,
                      prefixIcon:
                          const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: oc.icons,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ] else ...[
                  PhoneField(
                    initialValue: _phoneE164,
                    onChanged: (v) => setState(() => _phoneE164 = v),
                  ),
                ],
                const SizedBox(height: 28),

                // ---- CTA ----
                _loading
                    ? const Center(
                        child: SizedBox(
                          height: 48,
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _mode == _AuthMode.mail
                              ? _signUpEmail
                              : _signUpPhone,
                          child: Text(l10n.signUpButton),
                        ),
                      ),
                const SizedBox(height: 24),

                // ---- Footer link ----
                Text.rich(
                  TextSpan(
                    text: l10n.signUpHaveAccount,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: oc.secondaryText,
                        ),
                    children: [
                      TextSpan(
                        text: l10n.signUpSignIn,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: oc.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.go(AppRoutes.signIn),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mail / Phone toggle widget
// ---------------------------------------------------------------------------

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;

    return Container(
      decoration: BoxDecoration(
        color: oc.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oc.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTab(
            context,
            icon: Icons.email_outlined,
            label: 'Mail',
            isActive: mode == _AuthMode.mail,
            onTap: () => onChanged(_AuthMode.mail),
          ),
          _buildTab(
            context,
            icon: Icons.phone_outlined,
            label: 'Phone',
            isActive: mode == _AuthMode.phone,
            onTap: () => onChanged(_AuthMode.phone),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final oc = context.oc;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? oc.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : oc.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : oc.secondaryText,
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
// Logo — white card wrapper in dark mode so the dark navy logo stays visible
// ---------------------------------------------------------------------------

class _AuthLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final logo = Image.asset(
      'assets/images/logo_icon_cropped.png',
      height: 160,
    );

    if (!isDark) return logo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: logo,
    );
  }
}

// ---------------------------------------------------------------------------
// Theme toggle button — cycles system → light → dark
// ---------------------------------------------------------------------------

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final current = ref.watch(themeModeProvider);

    final (icon, next, label) = switch (current) {
      ThemeMode.light => (
          Icons.dark_mode_outlined,
          ThemeMode.dark,
          l10n.themeDark,
        ),
      ThemeMode.dark => (
          Icons.brightness_auto_outlined,
          ThemeMode.system,
          l10n.themeAuto,
        ),
      _ => (
          Icons.light_mode_outlined,
          ThemeMode.light,
          l10n.themeLight,
        ),
    };

    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            ref.read(themeModeProvider.notifier).setThemeMode(next),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: oc.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: oc.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: oc.primaryText),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: oc.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
