import 'package:cloud_functions/cloud_functions.dart';
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
// Auth mode + phone step enums
// ---------------------------------------------------------------------------

enum _AuthMode { mail, phone }

enum _PhoneStep { enterDetails, enterOtp }

/// Best-effort country detection from an E.164 phone prefix.
/// Defaults to FR if the prefix is anything other than +221 (Senegal).
String _countryFromPhone(String phoneE164) {
  if (phoneE164.startsWith('+221')) return 'SN';
  return 'FR';
}

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  _AuthMode _mode = _AuthMode.mail;
  _PhoneStep _phoneStep = _PhoneStep.enterDetails;

  // Shared
  final _nameController = TextEditingController();

  // Email fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Phone fields
  String? _phoneE164;
  final _otpController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Email sign-up — password + one-time verification email
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

    setState(() => _loading = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signUpWithEmailPassword(
            displayName: name,
            email: email,
            password: password,
          );
      // authStateChanges fires; router redirects to /home. The verification
      // mail has been dispatched and can be re-sent from the profile screen.
    } on FirebaseAuthException catch (e) {
      _showError(_mapFirebaseError(e.code));
    } catch (_) {
      _showError(l10n.errorGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Phone sign-up — OTP flow (Twilio Verify backend)
  // ---------------------------------------------------------------------------

  /// Step 1: validate name + phone, request an OTP, transition to step 2.
  Future<void> _requestOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final phone = _phoneE164;

    if (name.isEmpty || phone == null || phone.isEmpty) {
      _showError(l10n.signUpErrorEmptyFields);
      return;
    }
    final phoneError = PhoneField.validate(phone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() {
        _phoneStep = _PhoneStep.enterOtp;
        _otpController.clear();
      });
    } on FirebaseFunctionsException {
      _showError(l10n.authErrorOtpSend);
    } catch (_) {
      _showError(l10n.errorGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 2: verify the code; on success creates the account server-side and
  /// signs the user in via custom token.
  Future<void> _verifyAndSignUp() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final phone = _phoneE164;
    final code = _otpController.text.trim();

    if (name.isEmpty || phone == null || code.isEmpty) {
      _showError(l10n.signUpErrorEmptyFields);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .phoneSignUpWithOtp(
            phoneE164: phone,
            code: code,
            displayName: name,
            country: _countryFromPhone(phone),
          );
      // authStateChanges handles redirect.
    } on InvalidOtpException {
      _showError(l10n.authErrorInvalidOtp);
    } on PhoneTakenException {
      _showError(l10n.authErrorPhoneTaken);
    } catch (_) {
      _showError(l10n.errorGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editDetails() {
    setState(() {
      _phoneStep = _PhoneStep.enterDetails;
      _otpController.clear();
    });
  }

  VoidCallback? _ctaAction() {
    if (_mode == _AuthMode.mail) return _signUpEmail;
    return _phoneStep == _PhoneStep.enterDetails
        ? _requestOtp
        : _verifyAndSignUp;
  }

  String _ctaLabel(AppLocalizations l10n) {
    if (_mode == _AuthMode.mail) return l10n.signUpButton;
    return _phoneStep == _PhoneStep.enterDetails
        ? l10n.phoneOtpSendCode
        : l10n.signUpButton;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          // Explicit back button — context.go() to /sign-in replaces the stack
          // so the default Material back arrow wouldn't be shown.
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.signUpSignIn,
            onPressed: () => context.go(AppRoutes.signIn),
          ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ---- Mail / Phone toggle ----
                _AuthModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 28),

                // ---- Mode-specific fields ----
                if (_mode == _AuthMode.mail) ...[
                  // Name + email + password
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: l10n.signUpNameHint,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: oc.icons,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: oc.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: oc.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.signUpVerificationNotice,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_phoneStep == _PhoneStep.enterDetails) ...[
                  // Step 1 — name + phone
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: l10n.signUpNameHint,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PhoneField(
                    initialValue: _phoneE164,
                    onChanged: (v) => setState(() => _phoneE164 = v),
                  ),
                ] else ...[
                  // Step 2 — OTP code
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: oc.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: oc.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 18, color: oc.icons),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _phoneE164 ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _editDetails,
                          child: Text(l10n.phoneOtpEditNumber),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verifyAndSignUp(),
                    decoration: InputDecoration(
                      hintText: l10n.phoneOtpHint,
                      prefixIcon: const Icon(Icons.sms_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _requestOtp,
                      child: Text(l10n.phoneOtpResend),
                    ),
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
                          onPressed: _ctaAction(),
                          child: Text(_ctaLabel(l10n)),
                        ),
                      ),
                const SizedBox(height: 24),

                // ---- Footer link ----
                Text.rich(
                  TextSpan(
                    text: l10n.signUpHaveAccount,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
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
      _ => (Icons.light_mode_outlined, ThemeMode.light, l10n.themeLight),
    };

    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(next),
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
