import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/theme/theme_provider.dart';
import '../../../l10n/app_localizations.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError(l10n.signInErrorEmptyFields);
      return;
    }

    // Capture before async gap.
    final errorGeneral = l10n.errorGeneral;

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showError(_mapFirebaseError(e.code));
    } catch (_) {
      _showError(errorGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _mapFirebaseError(String code) {
    final l10n = AppLocalizations.of(context)!;
    return switch (code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        l10n.authErrorInvalidCredential,
      'user-disabled' => l10n.authErrorAccountDisabled,
      'too-many-requests' => l10n.authErrorTooManyRequests,
      _ => l10n.authErrorSignInFailed,
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
                const SizedBox(height: 40),

                // ---- Heading ----
                Text(
                  l10n.signInWelcome,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.signInSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: oc.secondaryText,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // ---- Fields ----
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
                  onSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    hintText: l10n.signInPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: oc.icons,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // ---- Forgot password ----
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final innerL10n = AppLocalizations.of(context)!;
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(innerL10n.signInForgotEnterEmail),
                            backgroundColor: oc.error,
                          ),
                        );
                        return;
                      }
                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: email);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .signInForgotEmailSent),
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .signInForgotEmailError),
                              backgroundColor: oc.error,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      l10n.signInForgotPassword,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: oc.primary,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

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
                          onPressed: _signIn,
                          child: Text(l10n.signInButton),
                        ),
                      ),
                const SizedBox(height: 24),

                // ---- Footer link ----
                Text.rich(
                  TextSpan(
                    text: l10n.signInNoAccount,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: oc.secondaryText,
                        ),
                    children: [
                      TextSpan(
                        text: l10n.signInRegister,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: oc.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.go(AppRoutes.signUp),
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
// Logo — white card wrapper in dark mode so the dark navy logo stays visible
// ---------------------------------------------------------------------------

class _AuthLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final logo = Image.asset(
      'assets/images/logo_outalma.png',
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
