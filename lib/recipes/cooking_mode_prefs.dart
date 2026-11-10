import "package:shared_preferences/shared_preferences.dart";

/// Cooking-mode settings kept on the phone.
class CookingModePrefs {
  const CookingModePrefs._();

  static const _handWaveKey = "cooking_hand_wave_enabled";
  static const _handWaveHintKey = "cooking_hand_wave_hint_seen";

  /// Hand wave is on unless the user turned it off.
  static Future<bool> handWaveEnabled() => _getBool(_handWaveKey, fallback: true);

  static Future<void> setHandWaveEnabled(bool enabled) => _setBool(_handWaveKey, enabled);

  static Future<bool> handWaveHintSeen() => _getBool(_handWaveHintKey, fallback: false);

  static Future<void> markHandWaveHintSeen() => _setBool(_handWaveHintKey, true);

  static Future<bool> _getBool(String key, {required bool fallback}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> _setBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // A setting that doesn't stick isn't worth an error.
    }
  }
}
