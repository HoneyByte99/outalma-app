// ScrollSafeCenter: a Center that scrolls when its box is too small.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outalma_app/src/features/shared/scroll_safe_center.dart';

const _childKey = Key('child');

Widget _host(double height, Widget center) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: height, child: center),
    ),
  ),
);

void main() {
  testWidgets('lays out exactly like Center when the child fits', (
    tester,
  ) async {
    const child = SizedBox(key: _childKey, width: 100, height: 50);
    await tester.pumpWidget(_host(200, const Center(child: child)));
    final plain = tester.getRect(find.byKey(_childKey));

    await tester.pumpWidget(_host(200, const ScrollSafeCenter(child: child)));
    expect(tester.getRect(find.byKey(_childKey)), plain);
  });

  testWidgets('scrolls instead of overflowing when the child is taller', (
    tester,
  ) async {
    const child = SizedBox(key: _childKey, width: 100, height: 400);
    // A plain Center would throw a RenderFlex-like overflow in a Column; here
    // the child is simply taller than the 120 px box.
    await tester.pumpWidget(_host(120, const ScrollSafeCenter(child: child)));
    // No exception so far. The bottom of the child is off the box...
    expect(tester.getRect(find.byKey(_childKey)).bottom, greaterThan(120));
    // ...and a drag brings it back in.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(_childKey)).bottom,
      lessThanOrEqualTo(120),
    );
  });
}
