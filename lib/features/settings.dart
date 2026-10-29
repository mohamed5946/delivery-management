// App settings for Delivery Management (Application tab).
// Only real, working settings: theme mode (persisted) — nothing
// decorative, nothing dead.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  // DeliveryFlow's default is its light glassy look — never
  // system-dark. A stored 'system' choice is still honored; only
  // the DEFAULT (no stored value, or an unknown value) is light.
  ThemeMode themeMode = ThemeMode.light;

  static const _themeKey = 'dm_theme_mode';

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
    } catch (_) {
      themeMode = ThemeMode.light;
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
}
