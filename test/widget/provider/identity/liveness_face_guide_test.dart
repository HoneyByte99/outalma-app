import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/domain/identity/liveness_challenge.dart';
import 'package:outalma_app/src/features/provider/identity/liveness_face_guide.dart';

Widget _wrap(LivenessState state) => MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: LivenessFaceGuide(state: state)),
  ),
);

/// The painter currently driving the drawn face.
CustomPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(LivenessFaceGuide),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return paint.painter!;
}

double _arrowOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(LivenessFaceGuide),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  // No pumpAndSettle anywhere in this file: the turnHead state loops on
  // purpose (the gesture has to keep being demonstrated), so settling would
  // never converge. Bounded pumps only.

  testWidgets('renders in every liveness state without failing', (
    tester,
  ) async {
    for (final state in LivenessState.values) {
      await tester.pumpWidget(_wrap(state));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(LivenessFaceGuide),
        findsOneWidget,
        reason: 'state $state must render',
      );
    }
    // Guards against a state being added without a branch here.
    expect(LivenessState.values, hasLength(6));
  });

  testWidgets('carries a screen-reader label (A5)', (tester) async {
    await tester.pumpWidget(_wrap(LivenessState.turnHead));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.bySemanticsLabel('Démonstration du mouvement à faire avec la tête.'),
      findsOneWidget,
    );
  });

  testWidgets('demonstrates the turn while one is being asked for', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(LivenessState.turnHead));
    await tester.pump(const Duration(milliseconds: 100));
    final first = _painter(tester);

    await tester.pump(const Duration(milliseconds: 300));
    final later = _painter(tester);

    expect(
      later,
      isNot(same(first)),
      reason: 'the face must keep moving while a turn is asked for',
    );
  });

  testWidgets('rests once the challenge is ready', (tester) async {
    await tester.pumpWidget(_wrap(LivenessState.ready));
    await tester.pump(const Duration(milliseconds: 100));
    final first = _painter(tester);

    await tester.pump(const Duration(milliseconds: 600));

    expect(
      _painter(tester),
      same(first),
      reason: 'a settled state must not keep repainting',
    );
  });

  testWidgets('the direction arrow shows only while a turn is asked for', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(LivenessState.turnHead));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_arrowOpacity(tester), 1);

    await tester.pumpWidget(_wrap(LivenessState.ready));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      _arrowOpacity(tester),
      0,
      reason: 'nothing left to point at once the face is back',
    );
  });
}
