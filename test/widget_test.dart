// Smoke test — verifies that the app widget tree boots without crashing.
// OutlamaApp requires ProviderScope since it is a ConsumerWidget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outalma_app/src/app/app.dart';

void main() {
  testWidgets('Smoke test — app boots with ProviderScope', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OutlamaApp(),
      ),
    );

    // The app should render a router-backed MaterialApp variant.
    expect(find.byType(Router<Object>), findsOneWidget);
  });
}
