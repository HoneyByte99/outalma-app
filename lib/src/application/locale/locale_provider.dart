import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'locale';

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _loadFromPrefs();
    return null; // null = follow device locale
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null) {
      _apply(Locale(code));
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _apply(locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, locale.languageCode);
    }
  }

  void _apply(Locale? locale) {
    state = locale;
    Intl.defaultLocale =
        locale != null ? '${locale.languageCode}_${locale.languageCode.toUpperCase()}' : null;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
