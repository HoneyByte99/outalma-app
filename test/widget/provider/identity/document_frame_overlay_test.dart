import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/l10n/app_localizations.dart';
import 'package:outalma_app/src/app/app_theme.dart';
import 'package:outalma_app/src/application/identity/document_shutter.dart';
import 'package:outalma_app/src/features/provider/identity/identity_capture_widgets.dart';

/// A3 for every shutter reason: meaning is never carried by colour alone, so
/// each one must render an icon, and the screen prints the matching text beside
/// it.
///
/// This file exists because the coverage of the increment named the gap: the
/// `tooClose` icon and its label were reached by no test at all. The unit tests
/// proved the shutter REACHES that reason; nothing proved the screen could say
/// anything about it. A reason with no icon is a blank circle for a provider who
/// cannot read.
///
/// It also covers the seven pre-existing reasons, which had no widget test
/// either: the overlay was only ever exercised through the page's message
/// assertions.
Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Stack(fit: StackFit.expand, children: [child]),
    ),
  );
}

void main() {
  testWidgets('every reason renders an icon, the three new ones included', (
    tester,
  ) async {
    for (final reason in DocumentShutterReason.values) {
      await tester.pumpWidget(_wrap(DocumentFrameOverlay(reason: reason)));
      await tester.pumpAndSettle();

      final icons = find.byType(Icon);
      expect(
        icons,
        findsWidgets,
        reason: '$reason must carry an icon, never colour alone (A3)',
      );
      final icon = tester.widget<Icon>(icons.first);
      expect(icon.icon, isNotNull, reason: '$reason');
      expect(icon.color, isNotNull, reason: '$reason');
    }
  });

  testWidgets('the three framing reasons are visually distinct', (
    tester,
  ) async {
    // Telling someone who is too close to come closer is the nonsense the three
    // separate reasons exist to prevent, so their icons must differ.
    final icons = <DocumentShutterReason, IconData>{};
    for (final reason in const [
      DocumentShutterReason.noDocument,
      DocumentShutterReason.tooSmall,
      DocumentShutterReason.tooClose,
    ]) {
      await tester.pumpWidget(_wrap(DocumentFrameOverlay(reason: reason)));
      await tester.pumpAndSettle();
      icons[reason] = tester.widget<Icon>(find.byType(Icon).first).icon!;
    }
    expect(icons.values.toSet(), hasLength(3));
  });

  testWidgets('the template yields the floor once the contour is up', (
    tester,
  ) async {
    // Two rectangles saying different things disorient someone who cannot read.
    // The template is not removed, it stops speaking: the state colour moves
    // onto the contour and the ring stops running.
    await tester.pumpWidget(
      _wrap(
        const DocumentFrameOverlay(
          reason: DocumentShutterReason.steadying,
          progress: 0.5,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final speaking = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(CustomPaint),
      ),
    );

    await tester.pumpWidget(
      _wrap(
        const DocumentFrameOverlay(
          reason: DocumentShutterReason.steadying,
          progress: 0.5,
          contourVisible: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final yielding = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(CustomPaint),
      ),
    );

    expect(
      yielding.painter,
      isNot(equals(speaking.painter)),
      reason: 'the template must paint differently once the contour is up',
    );
  });
}
