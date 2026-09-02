import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test bootstrap (auto-discovered by `flutter test`).
///
/// - Disables GoogleFonts runtime fetching so tests never hit the network.
/// - Loads every bundled font family (notably `MaterialIcons`) so golden
///   snapshots render real icon glyphs instead of empty boxes. Without this,
///   the category chips would golden as unreadable rectangles.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadBundledFonts();
  await testMain();
}

Future<void> _loadBundledFonts() async {
  final manifestRaw = await rootBundle.loadString('FontManifest.json');
  final manifest = (json.decode(manifestRaw) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    final fonts = (entry['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final font in fonts) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
