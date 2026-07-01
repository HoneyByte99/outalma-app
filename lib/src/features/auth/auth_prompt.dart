import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';

/// Bottom sheet shown when a guest triggers a login-gated action.
///
/// Keeps the current screen behind it (context preserved) and, after auth,
/// returns to [redirect] - which may itself carry an intent to resume, e.g.
/// `/service/:id?book=1` to reopen the booking sheet automatically.
Future<void> showAuthPrompt(
  BuildContext context, {
  required String reason,
  required String redirect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.oc.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXLarge),
      ),
    ),
    builder: (_) => _AuthPromptSheet(reason: reason, redirect: redirect),
  );
}

class _AuthPromptSheet extends StatelessWidget {
  const _AuthPromptSheet({required this.reason, required this.redirect});

  final String reason;
  final String redirect;

  String _authRoute(String base) =>
      Uri(path: base, queryParameters: {'redirect': redirect}).toString();

  void _goTo(BuildContext context, String base) {
    // Capture the router before popping the sheet (the builder context is
    // disposed once the sheet closes).
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(_authRoute(base));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.l,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: oc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: oc.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_open_rounded, color: oc.primary, size: 28),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goTo(context, AppRoutes.signIn),
                child: Text(l10n.signInButton),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _goTo(context, AppRoutes.signUp),
                child: Text(l10n.signUpButton),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.authPromptKeepBrowsing,
                style: TextStyle(color: oc.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
