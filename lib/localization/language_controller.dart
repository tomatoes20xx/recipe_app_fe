import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

class LanguageController extends ChangeNotifier {
  static const _kLanguageKey = "language_code";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Locale _locale = const Locale("en");

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  LanguageController() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final savedLanguage = await _storage.read(key: _kLanguageKey);
      if (savedLanguage != null) {
        _locale = Locale(savedLanguage);
        notifyListeners();
      }
    } catch (e) {
      // If loading fails, use default (English)
    }
  }

  Future<void> setLanguage(Locale locale) async {
    _locale = locale;
    await _storage.write(key: _kLanguageKey, value: locale.languageCode);
    notifyListeners();
  }

  Future<void> setLanguageCode(String languageCode) async {
    await setLanguage(Locale(languageCode));
  }
}
