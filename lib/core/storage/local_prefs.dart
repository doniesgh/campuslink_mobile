import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive preferences (theme, locale...).
class LocalPrefs {
  const LocalPrefs(this._prefs);
  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';

  ThemeMode get themeMode => switch (_prefs.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);
}
