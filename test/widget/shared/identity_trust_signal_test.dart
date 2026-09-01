// Widget tests for IdentityTrustSignal.
//
// Two things are being protected here, and they pull in opposite directions.
//
// The pill keeps its three states: it answers "where do I stand", a PROVIDER
// question, and folding two states together there would hide a real one.
//
// The badge keeps exactly ONE: it answers "can I trust this provider", a CLIENT
// question, and only `verified` answers it. The muted glyphs it used to render
// were 15 px and label-less, so they did not actually distinguish anything, and
// putting one on every card at launch (when almost nobody is verified) made the
// green check disappear into the noise it was supposed to stand out from.
//
// Common to both: while the projection has not been read, or if the read fails,
// the slot must be EMPTY. Showing "identity not verified" there publishes a
// false claim about a provider who may well be verified, every time the network
// coughs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/domain/enums/identity_trust_status.dart';
import 'package:outalma_app/src/features/shared/identity_trust_signal.dart';

const _uid = 'provider-1';

Widget _wrap(
  Stream<IdentityTrustStatus?> stream, {
  TrustSignalStyle style = TrustSignalStyle.pill,
}) {
  return ProviderScope(
    overrides: [identityTrustProvider(_uid).overrideWith((ref) => stream)],
    child: MaterialApp(
      // French explicitly: the assertions below read the labels a Senegalese
      // or French provider actually sees. Left to resolve on its own, the test
      // host picks English and the assertions would test nothing.
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: IdentityTrustSignal(providerId: _uid, style: style),
        ),
      ),
    ),
  );
}

/// The three states mounted SIDE BY SIDE in one scope.
///
/// Looping with pumpWidget reuses the ProviderScope element, so the override
/// never changes and all three reads return the same status: such a test would
/// compare an icon to itself and pass with one glyph for three states.
Widget wrapAllThree({TrustSignalStyle style = TrustSignalStyle.badge}) {
  return ProviderScope(
    overrides: [
      identityTrustProvider(
        'verified',
      ).overrideWith((_) => Stream.value(IdentityTrustStatus.verified)),
      identityTrustProvider(
        'pending',
      ).overrideWith((_) => Stream.value(IdentityTrustStatus.pending)),
      identityTrustProvider('absent').overrideWith((_) => Stream.value(null)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            IdentityTrustSignal(providerId: 'verified', style: style),
            IdentityTrustSignal(providerId: 'pending', style: style),
            IdentityTrustSignal(providerId: 'absent', style: style),
          ],
        ),
      ),
    ),
  );
}

void main() {
  _badgeIsVerifiedOnlyTests();

  group('full form', () {
    testWidgets('shows nothing while the projection has not been read', (
      tester,
    ) async {
      // A stream that never emits: this is the state a client is in for the
      // first frames of every screen, and on a slow link for much longer.
      await tester.pumpWidget(
        _wrap(const Stream<IdentityTrustStatus?>.empty()),
      );
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows nothing when the read fails', (tester) async {
      await tester.pumpWidget(
        _wrap(Stream<IdentityTrustStatus?>.error(Exception('offline'))),
      );
      await tester.pump();
      // Not "not verified": a failed read says nothing about the person.
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('says not verified when the document is absent', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(Stream.value(null)));
      await tester.pump();
      expect(find.text('Identité non vérifiée'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('says under way while pending', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _wrap(Stream.value(IdentityTrustStatus.pending)),
        ),
      );
      await tester.pump();
      expect(find.text('Vérification en cours'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('says verified when verified', (tester) async {
      await tester.pumpWidget(
        _wrap(Stream.value(IdentityTrustStatus.verified)),
      );
      await tester.pump();
      expect(find.text('Profil vérifié'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('every state carries an icon AND a text, never colour alone', (
      tester,
    ) async {
      for (final status in [
        null,
        IdentityTrustStatus.pending,
        IdentityTrustStatus.verified,
      ]) {
        await tester.pumpWidget(_wrap(Stream.value(status)));
        await tester.pump();
        expect(find.byType(Icon), findsOneWidget, reason: 'state $status');
        expect(find.byType(Text), findsOneWidget, reason: 'state $status');
      }
    });
  });

  group('badge form, beside a name', () {
    testWidgets('a verified provider gets the tinted check', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Stream.value(IdentityTrustStatus.verified),
          style: TrustSignalStyle.badge,
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.byType(Text), findsNothing, reason: 'a badge, not a label');
    });

    testWidgets('an UNVERIFIED provider renders NOTHING in badge style', (
      tester,
    ) async {
      // The contract of this task. A muted shield on every card at launch, when
      // almost nobody is verified, IS the background: it made the green check
      // one variation in a wall of grey instead of a signal. And at 15 px with
      // no label it never distinguished the states anyway.
      await tester.pumpWidget(
        _wrap(Stream.value(null), style: TrustSignalStyle.badge),
      );
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        find.bySemanticsLabel('Identité non vérifiée'),
        findsNothing,
        reason: 'a client surface makes no claim about an unverified provider',
      );
    });

    testWidgets('a PENDING provider renders NOTHING in badge style', (
      tester,
    ) async {
      // `pending` is an internal state a client cannot act on. It stays on the
      // provider's own surfaces, which do not go through this widget.
      await tester.pumpWidget(
        _wrap(
          Stream.value(IdentityTrustStatus.pending),
          style: TrustSignalStyle.badge,
        ),
      );
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(
        find.bySemanticsLabel('Vérification en cours'),
        findsNothing,
        reason: 'announcing an internal state to a client is noise, not trust',
      );
    });

    testWidgets('an unresolved read shows nothing at all', (tester) async {
      // No icon, no label: claiming anything while the read is in flight
      // publishes a false statement about a real person.
      await tester.pumpWidget(
        _wrap(const Stream.empty(), style: TrustSignalStyle.badge),
      );
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('the PILL still carries all three states', (tester) async {
      // Guard against "simplify the badge" quietly becoming "simplify the
      // widget". The provider-facing form must keep saying where they stand.
      //
      // Mounted side by side rather than looped, for the reason spelled out on
      // wrapAllThree below: looping pumpWidget reuses the ProviderScope element
      // so the override never changes, and all three would read one status.
      await tester.pumpWidget(wrapAllThree(style: TrustSignalStyle.pill));
      await tester.pump();
      await tester.pump();

      for (final label in [
        'Profil vérifié',
        'Vérification en cours',
        'Identité non vérifiée',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'pill state $label');
      }
    });
  });
}

// Mounts the three states SIDE BY SIDE in one scope. This is the shape of the
// real catalogue: many providers on one screen, almost none of them verified.
// It is the test that actually proves the noise is gone, because it counts what
// renders across all three at once rather than one state at a time.
void _badgeIsVerifiedOnlyTests() {
  group('badge: verified only, side by side', () {
    testWidgets('ONE glyph renders for three providers, the verified one', (
      tester,
    ) async {
      await tester.pumpWidget(wrapAllThree());
      await tester.pump();
      await tester.pump();

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();

      expect(
        icons,
        [Icons.verified_rounded],
        reason:
            'three providers, one badge: the check is only a signal if the '
            'two states that say nothing useful render nothing at all',
      );
    });

    testWidgets('only the verified provider is announced', (tester) async {
      await tester.pumpWidget(wrapAllThree());
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Profil vérifié'), findsOneWidget);
      for (final label in ['Vérification en cours', 'Identité non vérifiée']) {
        expect(
          find.bySemanticsLabel(label),
          findsNothing,
          reason: 'a client surface announces trust, not its absence',
        );
      }
    });

    testWidgets('the badge shows NO visible text, unlike the pill', (
      tester,
    ) async {
      // This is what removes "Identite non verifiee" from the public profile.
      await tester.pumpWidget(wrapAllThree());
      await tester.pump();
      await tester.pump();
      expect(find.byType(Text), findsNothing);
    });
  });
}
