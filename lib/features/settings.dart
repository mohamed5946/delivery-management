// App settings for Delivery Management (Application tab).
// Only real, working settings: theme mode + language (persisted) —
// nothing decorative, nothing dead.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  // DeliveryFlow's default is its light glassy look — never
  // system-dark. A stored 'system' choice is still honored; only
  // the DEFAULT (no stored value, or an unknown value) is light.
  ThemeMode themeMode = ThemeMode.light;

  /// App language. Arabic is the default (current language);
  /// English switches the whole UI and flips to LTR.
  Locale locale = const Locale('ar');

  static const _themeKey = 'dm_theme_mode';
  static const _localeKey = 'dm_locale';

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_themeKey);
      themeMode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      locale = switch (_prefs!.getString(_localeKey)) {
        'en' => const Locale('en'),
        _ => const Locale('ar'),
      };
    } catch (_) {
      themeMode = ThemeMode.light;
      locale = const Locale('ar');
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        _themeKey,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (_) {}
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        _localeKey,
        value.languageCode == 'en' ? 'en' : 'ar',
      );
    } catch (_) {}
  }
}
