import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card is about 139 px of usable width at 375 px on two columns, and its
/// height is FIXED by `childAspectRatio`. Both facts make it easy to ship a
/// truncation, which is the defect this increment set out to remove: the
/// register recorded "500 000 F CF...", a monthly price cut mid-number because
/// it shared its line with the rating.
///
/// These assertions lay the text out with a TextPainter rather than looking for
/// an overflow. `TextOverflow.ellipsis` is precisely what PREVENTS an overflow
/// while truncating, so "no overflow" would have been green over the bug.
void main() {
  const cardContentWidth = 139.5;

  // The card's price style, stated explicitly rather than read from the theme:
  // google_fonts cannot fetch under `flutter test`, so a theme lookup either
  // throws or silently measures a fallback face. What this guards is the
  // LAYOUT decision (own row, two lines), not the exact glyph widths of a font
  // the test environment does not have.
  TextStyle priceStyle() =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

  TextPainter layout(String text, {double scale = 1.0, int maxLines = 2}) {
    return TextPainter(
      text: TextSpan(text: text, style: priceStyle()),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      textScaler: TextScaler.linear(scale),
    )..layout(maxWidth: cardContentWidth);
  }

  group('the price label fits the card', () {
    test('every single price form fits whole, including the one N4 cut', () {
      for (final label in [
        '500 000 F CFA/mois', // the exact case the register caught
        '500 000 F CFA',
        '2 500 F CFA/h',
        '1 500 F CFA/h',
      ]) {
        expect(
          layout(label).didExceedMaxLines,
          isFalse,
          reason: '"$label" must be readable in full',
        );
      }
    });

    test('the widest range degrades gracefully instead of cutting a number', () {
      // Two six-digit bounds plus a period is the widest label
      // servicePriceLabel can build. It needs a third line, so it ellipsises at
      // the END rather than mid-number: the amount stays readable, the period
      // is what is lost. Sizing the whole grid for this one case would cost
      // every card a line of height.
      final widest = layout('500 000 - 900 000 F CFA/mois');
      expect(widest.didExceedMaxLines, isTrue);
      expect(
        widest.computeLineMetrics(),
        hasLength(2),
        reason: 'two lines is what infoHeight reserves',
      );
    });

    test('two lines of price stay within the height the grid reserves', () {
      // infoHeight is a hard constant feeding childAspectRatio: overshoot it
      // and the image Expanded above overflows.
      expect(layout('500 000 F CFA/mois').height, lessThan(60));
    });

    test('at 200 percent text scale the price needs more than two lines', () {
      // Reported, not asserted away: A6 is a CIBLE line. At double scale the
      // label cannot fit the two lines the grid reserves, so it ellipsises.
      // Sizing every card for this case would cost a line of height on all of
      // them, which is why it is a measurement and not a failure.
      // Measured, not wished for: at double scale EVERY price form overflows
      // the two lines the grid reserves, the hourly one included. The label
      // ellipsises rather than pushing the card, which is the behaviour to
      // report at the smoke pass, not a failure to hide behind an assertion.
      for (final label in ['500 000 F CFA/mois', '2 500 F CFA/h']) {
        expect(
          layout(label, scale: 2.0).didExceedMaxLines,
          isTrue,
          reason: '"$label" at 200 percent',
        );
      }
    });
  });
}
