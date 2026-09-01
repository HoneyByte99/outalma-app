import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';

/// Carries the current `?redirect=` target onto another auth route, so hopping
/// between sign-in and sign-up (or the phone "no account yet" bounce) does not
/// silently drop what the visitor was trying to do.
String authRouteWithRedirect(BuildContext context, String base) {
  final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
  if (redirect == null || redirect.isEmpty) return base;
  return Uri(path: base, queryParameters: {'redirect': redirect}).toString();
}

/// Invitation shown when a visitor with no account triggers a gated action.
///
/// A sheet, not a redirect: the screen the visitor chose stays visible behind
/// it, so declining costs one tap and loses nothing. It states what an account
/// is FOR before asking for one, and its third option is to carry on browsing:
/// a visitor who is still deciding is not a visitor to push out.
///
/// After signing in, [redirect] is where they land. It may carry its own intent,
/// e.g. `/service/:id?book=1` to reopen the booking sheet they came for.
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
    // Capture the router BEFORE popping: the builder context is defunct once
    // the sheet closes, and reading GoRouter.of from it then throws.
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
            const SizedBox(height: AppSpacing.xs),
            // What they gain, not what they are missing. Without this line the
            // sheet is a wall with a reason on it.
            Text(
              l10n.authPromptBenefits,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goTo(context, AppRoutes.signUp),
                child: Text(l10n.signUpButton),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _goTo(context, AppRoutes.signIn),
                child: Text(l10n.signInButton),
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
