import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

class ThemeController extends ChangeNotifier {
  static const _kThemeKey = "theme_mode";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeController() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedTheme = await _storage.read(key: _kThemeKey);
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      // If loading fails, use system default
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _storage.write(key: _kThemeKey, value: _themeMode.toString());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.write(key: _kThemeKey, value: _themeMode.toString());
    notifyListeners();
  }
}
