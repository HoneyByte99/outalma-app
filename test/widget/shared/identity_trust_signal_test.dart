// Widget tests for IdentityTrustSignal.
//
// The four situations are the point of this widget, and the first one is the
// one that is easy to get wrong: while the projection has not been read, or if
// the read fails, the slot must be EMPTY. Showing "identity not verified" there
// publishes a false claim about a provider who may well be verified, every time
// the network coughs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/identity_trust_providers.dart';
import 'package:outalma_app/src/domain/enums/identity_trust_status.dart';
import 'package:outalma_app/src/features/shared/identity_trust_signal.dart';

const _uid = 'provider-1';

Widget _wrap(Stream<IdentityTrustStatus?> stream, {bool compact = false}) {
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
          child: IdentityTrustSignal(providerId: _uid, compact: compact),
        ),
      ),
    ),
  );
}

void main() {
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

  group('compact form, list cards', () {
    testWidgets('shows the icon only when verified', (tester) async {
      await tester.pumpWidget(
        _wrap(Stream.value(IdentityTrustStatus.verified), compact: true),
      );
      await tester.pump();
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows nothing for pending, absent or unread', (tester) async {
      // A negative state as a bare icon would be undecipherable, so the compact
      // form carries exactly one state and never has to be guessed.
      for (final status in [null, IdentityTrustStatus.pending]) {
        await tester.pumpWidget(_wrap(Stream.value(status), compact: true));
        await tester.pump();
        expect(find.byType(Icon), findsNothing, reason: 'state $status');
      }
    });
  });
}
