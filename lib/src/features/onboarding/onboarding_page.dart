import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/onboarding/onboarding_provider.dart';
import '../shared/marketplace_disclaimer.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  bool _termsAccepted = false;
  bool _showTermsError = false;

  static const _totalPages = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(AppLocalizations l10n) {
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  // "Skip" jumps to the last slide (where the terms checkbox + Get Started
  // live) instead of trying to finish - finishing requires terms acceptance,
  // which is only shown on the last slide.
  void _skipToEnd() {
    _controller.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Records consent, then opens the catalogue.
  ///
  /// The consent gate stays in FRONT of everything, guest browsing included,
  /// and that is a deliberate call rather than an oversight in the guest work.
  /// The last slide carries the marketplace disclaimer: Outalma introduces
  /// clients and providers and is not the employer of either. That statement
  /// protects the visitor and the company on the BROWSING surface, which is
  /// exactly where someone with no account forms their expectations. Collecting
  /// it after sign-up would leave every visitor who never signs up, most of
  /// them, having read nothing.
  ///
  /// What changed is only where the door leads: /home instead of /sign-in. One
  /// gate, one consent, then free browsing.
  Future<void> _finish() async {
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    await _persistConsent();
    if (mounted) context.go(AppRoutes.home);
  }

  /// Same consent, then straight to sign-in. Someone who already has an account
  /// must still pass the gate: this is the first launch on THIS device.
  Future<void> _goToSignIn() async {
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    await _persistConsent();
    if (mounted) context.go(AppRoutes.signIn);
  }

  Future<void> _persistConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final isLast = _page == _totalPages - 1;

    final slides = _buildSlides(l10n, oc);

    return Scaffold(
      backgroundColor: oc.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (not shown on last slide)
            Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: isLast ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: isLast ? null : _skipToEnd,
                  child: Text(
                    l10n.introSkip,
                    style: TextStyle(color: oc.secondaryText),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() {
                  _page = i;
                  _showTermsError = false;
                }),
                children: slides,
              ),
            ),

            // Dot indicators
            _DotsIndicator(
              count: _totalPages,
              current: _page,
              color: oc.primary,
            ),
            const SizedBox(height: 24),

            // Terms checkbox on last slide
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: isLast
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // How the marketplace works + the user's
                          // responsibility, shown before consent.
                          const MarketplaceDisclaimer(),
                          const SizedBox(height: 16),
                          // Read first, then decide: in-app links above the
                          // acceptance checkbox (no remote URL).
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            children: [
                              _LegalLink(
                                label: l10n.legalReadTerms,
                                onTap: () => context.push('/legal/terms'),
                                color: oc.primary,
                              ),
                              _LegalLink(
                                label: l10n.legalReadPrivacy,
                                onTap: () => context.push('/legal/privacy'),
                                color: oc.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => setState(() {
                              _termsAccepted = !_termsAccepted;
                              if (_termsAccepted) _showTermsError = false;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (v) => setState(() {
                                    _termsAccepted = v ?? false;
                                    if (_termsAccepted) _showTermsError = false;
                                  }),
                                  activeColor: oc.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    l10n.introTermsAccept,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: oc.primaryText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_showTermsError) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: oc.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    l10n.introTermsRequired,
                                    style: TextStyle(
                                      color: oc.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Action button
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, isLast ? 8 : 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _next(l10n),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    // The consent slide's CTA names where it leads. It used to
                    // read "Commencer" and land on the sign-in wall, which made
                    // the account look compulsory. It opens the catalogue now.
                    isLast ? l10n.introContinueAsGuest : l10n.introNext,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Sign-in for someone who already has an account, so the only path
            // to it is not "browse, then find the header button".
            if (isLast)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: TextButton(
                  onPressed: _goToSignIn,
                  child: Text(
                    l10n.introAlreadyHaveAccount,
                    style: TextStyle(color: oc.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSlides(AppLocalizations l10n, OutalmaColors oc) {
    final slides = [
      _Slide(
        icon: Icons.handshake_outlined,
        iconColor: oc.primary,
        title: l10n.introSlide1Title,
        body: l10n.introSlide1Body,
      ),
      _Slide(
        icon: Icons.calendar_month_outlined,
        iconColor: oc.primary,
        title: l10n.introSlide2Title,
        body: l10n.introSlide2Body,
      ),
      _Slide(
        icon: Icons.track_changes_outlined,
        iconColor: oc.primary,
        title: l10n.introSlide3Title,
        body: l10n.introSlide3Body,
      ),
      _Slide(
        icon: Icons.rocket_launch_outlined,
        iconColor: oc.primary,
        title: l10n.introSlide4Title,
        body: l10n.introSlide4Body,
      ),
    ];
    return slides;
  }
}

// ---------------------------------------------------------------------------
// Legal link (opens an in-app document, not a remote URL)
// ---------------------------------------------------------------------------

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide widget
// ---------------------------------------------------------------------------

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    // The last slide shrinks the PageView viewport (it also renders the
    // consent block below), so the slide content must stay scroll-safe:
    // centre when it fits, scroll instead of overflowing when the viewport
    // is short (~50px overflow reported on iPhone 15 Pro).
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo at top of every slide
                  Image.asset(
                    'assets/images/logo_icon_cropped.png',
                    height: 72,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 48),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: oc.secondaryText,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dot indicator
// ---------------------------------------------------------------------------

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.count,
    required this.current,
    required this.color,
  });

  final int count;
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
