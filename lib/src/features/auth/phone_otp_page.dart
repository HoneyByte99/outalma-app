import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';

class PhoneOtpPage extends ConsumerStatefulWidget {
  const PhoneOtpPage({super.key});

  @override
  ConsumerState<PhoneOtpPage> createState() => _PhoneOtpPageState();
}

class _PhoneOtpPageState extends ConsumerState<PhoneOtpPage> {
  final _codeController = TextEditingController();
  bool _loading = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthPhoneVerification) return;

    final l10n = AppLocalizations.of(context)!;
    final errMsg = l10n.otpError;
    setState(() => _loading = true);

    try {
      await ref.read(authNotifierProvider.notifier).verifyPhoneOtp(
            authState.verificationId,
            code,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: context.oc.error,
          ),
        );
        _codeController.clear();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthPhoneVerification) return;

    final l10n = AppLocalizations.of(context)!;
    final errMsg = l10n.otpPhoneError;
    setState(() => _loading = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendPhoneOtp(authState.phoneNumber);
      _startTimer();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final phoneNumber = authState is AuthPhoneVerification
        ? authState.phoneNumber
        : '';

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        backgroundColor: oc.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            // Go back to unauthenticated state
            ref.read(authNotifierProvider.notifier).signOut();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: oc.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sms_outlined, color: oc.primary, size: 28),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                l10n.otpTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.otpSubtitle(phoneNumber),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: oc.secondaryText,
                    ),
              ),
              const SizedBox(height: 40),

              // OTP field
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 12,
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: 12,
                        color: oc.border,
                      ),
                  filled: true,
                  fillColor: oc.inputFill,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: oc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: oc.primary, width: 2),
                  ),
                ),
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
              ),
              const SizedBox(height: 28),

              // Verify button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: oc.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l10n.otpVerify,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Resend
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        l10n.otpResendIn(_resendCountdown),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: oc.secondaryText,
                            ),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _resend,
                        child: Text(l10n.otpResend),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
