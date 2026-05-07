import "package:flutter/foundation.dart";

import "user_api.dart";

class StreakController extends ChangeNotifier {
  StreakController({required this.userApi});

  final UserApi userApi;

  int currentStreak = 0;
  int longestStreak = 0;
  String? lastCookedAt;
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final data = await userApi.getStreak();
      currentStreak = (data["current_streak"] as num?)?.toInt() ?? 0;
      longestStreak = (data["longest_streak"] as num?)?.toInt() ?? 0;
      lastCookedAt = data["last_cooked_at"] as String?;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Silent — streak is non-critical
    }
  }

  void updateFromCook(int streakDays) {
    currentStreak = streakDays;
    _loaded = true;
    notifyListeners();
  }
}
