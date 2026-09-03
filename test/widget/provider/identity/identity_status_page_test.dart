// The follow-up screen renders one distinct state per situation (AC-C16), shows
// the reviewer's reason verbatim (AC-C17), and offers a capture path only where
// a new submission is allowed (AC-C18/AC-C19). The record provider is overridden
// so no Firestore or auth is touched.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/app/router.dart';
import 'package:outalma_app/src/application/identity/identity_verification_providers.dart';
import 'package:outalma_app/src/domain/enums/identity_status.dart';
import 'package:outalma_app/src/domain/models/identity_verification_record.dart';
import 'package:outalma_app/src/features/provider/identity/identity_status_page.dart';

Widget _wrap(
  Stream<IdentityVerificationRecord?> stream, {
  VoidCallback? onStart,
}) {
  return ProviderScope(
    overrides: [myIdentityVerificationProvider.overrideWith((ref) => stream)],
    child: MaterialApp(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: IdentityStatusPage(onStartVerification: onStart ?? () {}),
    ),
  );
}

/// Router-backed harness for the two exit tests below: the leading button
/// calls `GoRouter.of(context)`, which needs a real GoRouter ancestor
/// (`MaterialApp`'s plain `home:` above has none).
Widget _wrapWithRouter(
  Stream<IdentityVerificationRecord?> stream,
  GoRouter router,
) {
  return ProviderScope(
    overrides: [myIdentityVerificationProvider.overrideWith((ref) => stream)],
    child: MaterialApp.router(
      locale: const Locale('fr'),
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

IdentityVerificationRecord _record({
  required IdentityStatus status,
  int attempt = 1,
  bool priority = false,
  String? reason,
}) {
  return IdentityVerificationRecord(
    status: status,
    attempt: attempt,
    priority: priority,
    rejectionReason: reason,
    submittedAt: DateTime.utc(2026, 8, 20),
    reviewedAt: DateTime.utc(2026, 8, 21),
  );
}

void main() {
  testWidgets('loading shows a spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(const Stream<IdentityVerificationRecord?>.empty()),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a read error shows an unavailable state with a retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(Stream<IdentityVerificationRecord?>.error(Exception('offline'))),
    );
    await tester.pump();
    expect(find.text('État indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('no file shows not verified with the start CTA', (tester) async {
    await tester.pumpWidget(_wrap(Stream.value(null)));
    await tester.pump();
    expect(find.text('Identité non vérifiée'), findsOneWidget);
    expect(find.text('Vérifier mon identité'), findsOneWidget);
  });

  testWidgets('pending shows under way and offers no action', (tester) async {
    await tester.pumpWidget(
      _wrap(Stream.value(_record(status: IdentityStatus.pending))),
    );
    await tester.pump();
    expect(find.text('Vérification en cours'), findsOneWidget);
    expect(find.text('Recommencer'), findsNothing);
    expect(find.text('Vérifier mon identité'), findsNothing);
  });

  testWidgets('approved shows verified and offers no action (AC-C18)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(Stream.value(_record(status: IdentityStatus.approved))),
    );
    await tester.pump();
    expect(find.text('Profil vérifié'), findsOneWidget);
    expect(find.text('Recommencer'), findsNothing);
  });

  testWidgets('rejected shows the reviewer reason verbatim and a restart', (
    tester,
  ) async {
    const reason = 'Photo du verso illisible, recommencez.';
    await tester.pumpWidget(
      _wrap(
        Stream.value(_record(status: IdentityStatus.rejected, reason: reason)),
      ),
    );
    await tester.pump();
    expect(find.text('Vérification refusée'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(find.text('Recommencer'), findsOneWidget);
  });

  testWidgets('the 4th rejection carries the priority note', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Stream.value(
          _record(
            status: IdentityStatus.rejected,
            attempt: 4,
            reason: 'Encore illisible.',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('traité en priorité'), findsOneWidget);
  });

  testWidgets('revoked shows withdrawn with a restart', (tester) async {
    await tester.pumpWidget(
      _wrap(Stream.value(_record(status: IdentityStatus.revoked))),
    );
    await tester.pump();
    expect(find.text('Vérification retirée'), findsOneWidget);
    expect(find.text('Recommencer'), findsOneWidget);
  });

  testWidgets('the capture CTA fires onStartVerification (navigation)', (
    tester,
  ) async {
    var started = false;
    await tester.pumpWidget(
      _wrap(Stream.value(null), onStart: () => started = true),
    );
    await tester.pump();
    await tester.tap(find.text('Vérifier mon identité'));
    await tester.pump();
    expect(started, isTrue);
  });

  // Regression: router.dart used go() (not push()) to reach this screen after
  // capture, which clears the whole navigation stack. A cold-start deep link
  // (e.g. a notification) produces the exact same "no stack" situation. Either
  // way, canPop() is false and, before this fix, the AppBar had no leading:
  // automaticallyImplyLeading had nothing to imply, and the screen had no
  // bottom nav (it lives outside the shell) - a dead end the user could only
  // escape by killing the app. This is the test that would have caught it.
  testWidgets(
    'no poppable stack (e.g. cold-start deep link): the leading button still '
    'exits, landing on the provider dashboard anchor',
    (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.identityStatus,
        routes: [
          GoRoute(
            path: AppRoutes.identityStatus,
            builder: (_, __) => IdentityStatusPage(onStartVerification: () {}),
          ),
          GoRoute(
            path: AppRoutes.providerHome,
            builder: (_, __) =>
                const Scaffold(body: Text('provider dashboard')),
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          Stream.value(_record(status: IdentityStatus.pending)),
          router,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        router.canPop(),
        isFalse,
        reason: 'sets up the exact trap: a single, unpoppable route',
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('provider dashboard'), findsOneWidget);
    },
  );

  testWidgets('a poppable stack (e.g. pushed from the dashboard hub line): the '
      'leading button pops back instead of leaving to the anchor', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/dashboard-stub',
      routes: [
        GoRoute(
          path: '/dashboard-stub',
          builder: (_, __) => const Scaffold(body: Text('dashboard stub')),
        ),
        GoRoute(
          path: AppRoutes.identityStatus,
          builder: (_, __) => IdentityStatusPage(onStartVerification: () {}),
        ),
        GoRoute(
          path: AppRoutes.providerHome,
          builder: (_, __) => const Scaffold(body: Text('provider dashboard')),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithRouter(
        Stream.value(_record(status: IdentityStatus.pending)),
        router,
      ),
    );
    await tester.pump();
    // Not awaited: push()'s Future only completes when the pushed route is
    // later popped (like Navigator.push), and that pop is exactly what the
    // tap below triggers - awaiting it here would deadlock the test on
    // itself.
    unawaited(router.push(AppRoutes.identityStatus));
    // Not pumpAndSettle: the stream provider is briefly in its loading state,
    // which renders an indeterminate CircularProgressIndicator whose
    // AnimationController repeats forever and would hang pumpAndSettle until
    // the data resolves. Two explicit pumps give the single-value stream's
    // microtask time to fire first (same reasoning as the "loading shows a
    // spinner" case above, which never calls pumpAndSettle either).
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('dashboard stub'), findsOneWidget);
    expect(find.text('provider dashboard'), findsNothing);
  });
}
