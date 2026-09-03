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
  group('colorFor', () {
    // Extracted from DocumentFrameOverlay's private `_color` so the live
    // contour (DocumentContourOverlay, in capture_document_page.dart) can
    // paint the SAME state colour instead of always falling back to its own
    // white default. Every reason listed explicitly: a missing branch here
    // is a reason silently painted white on both widgets.
    test('every reason maps to a colour, and every reason is covered', () {
      for (final reason in DocumentShutterReason.values) {
        expect(colorFor(reason), isNotNull, reason: '$reason');
      }
    });

    test('steadying and ready both signal the accent colour', () {
      expect(colorFor(DocumentShutterReason.steadying), AppColors.accent);
      expect(colorFor(DocumentShutterReason.ready), AppColors.accent);
    });

    test('the three "fix the framing" reasons all warn', () {
      expect(colorFor(DocumentShutterReason.refused), AppColors.warning);
      expect(colorFor(DocumentShutterReason.tooSmall), AppColors.warning);
      expect(colorFor(DocumentShutterReason.tooClose), AppColors.warning);
    });

    test('the neutral/unknown reasons stay white', () {
      for (final reason in [
        DocumentShutterReason.noFrame,
        DocumentShutterReason.waitingForMotion,
        DocumentShutterReason.tooBlurred,
        DocumentShutterReason.moving,
        DocumentShutterReason.noDocument,
      ]) {
        expect(colorFor(reason), Colors.white, reason: '$reason');
      }
    });
  });

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
    // The template is not removed, it stops speaking in colour: it fades to a
    // fixed white while the state colour moves onto the contour (painted by
    // the caller with colorFor, see capture_document_page.dart). The ring
    // itself keeps turning either way, since it is the hold's main signal
    // (document_shutter_framing_test.dart); it must not disappear at the exact
    // moment detection starts working. Verifying the painter actually differs
    // is as far as a widget test can see (`_DocumentFramePainter` is private
    // to the library); the one-line `progress: value` fix itself is covered
    // by `colorFor` staying wired through both overlays in
    // document_contour_geometry_test.dart.
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
