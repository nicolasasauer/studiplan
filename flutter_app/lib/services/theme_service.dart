import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// System, light or dark - remembered on this device only, it is not part of
/// the plan and does not sync.
class ThemeService extends ChangeNotifier {
  static const _kThemeMode = 'sp_theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeMode);
    final mode = ThemeMode.values.where((m) => m.name == stored).firstOrNull;
    if (mode != null && mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }
}
