import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../application/auth/auth_providers.dart';
import '../shared/phone_field.dart';

class PhoneSignInPage extends ConsumerStatefulWidget {
  const PhoneSignInPage({super.key});

  @override
  ConsumerState<PhoneSignInPage> createState() => _PhoneSignInPageState();
}

class _PhoneSignInPageState extends ConsumerState<PhoneSignInPage> {
  String? _phoneE164;
  bool _loading = false;

  Future<void> _send() async {
    if (kIsWeb) return; // button is disabled on web; defensive guard only
    final phone = _phoneE164;
    if (phone == null || phone.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final errMsg = l10n.otpPhoneError;
    setState(() => _loading = true);

    try {
      await ref.read(authNotifierProvider.notifier).sendPhoneOtp(phone);
      // Router auto-redirects to /auth/phone-otp on AuthPhoneVerification state.
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: oc.background,
        appBar: AppBar(
          backgroundColor: oc.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
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
                  child:
                      Icon(Icons.phone_outlined, color: oc.primary, size: 28),
                ),
                const SizedBox(height: 24),

                Text(
                  l10n.phoneAuthTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.phoneAuthSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: oc.secondaryText,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 36),

                PhoneField(
                  initialValue: null,
                  onChanged: (v) => setState(() => _phoneE164 = v),
                ),
                const SizedBox(height: 28),

                if (kIsWeb) ...[
                  // Persistent inline notice — web doesn't support phone auth.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: oc.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: oc.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.smartphone_rounded,
                            color: oc.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.phoneAuthWebUnsupported,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: oc.primary,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: null, // disabled on web
                      style: FilledButton.styleFrom(
                        backgroundColor: oc.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.phoneAuthButton,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_loading || (_phoneE164?.isEmpty ?? true))
                          ? null
                          : _send,
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
                              l10n.phoneAuthButton,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
