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

  /// Bumped by [clear] so a load that was in flight at sign-out is dropped.
  int _generation = 0;

  /// UTC dates (at midnight) covered by [currentStreak]. The server groups
  /// cooks by UTC date and counts the run that ends today or yesterday, and
  /// that run ends on the date of [lastCookedAt].
  Set<DateTime> get streakDatesUtc {
    final last = lastCookedAt == null ? null : DateTime.tryParse(lastCookedAt!)?.toUtc();
    if (currentStreak <= 0 || last == null) return const {};
    final end = DateTime.utc(last.year, last.month, last.day);
    return {for (var i = 0; i < currentStreak; i++) end.subtract(Duration(days: i))};
  }

  Future<void> load() async {
    final generation = _generation;
    try {
      final data = await userApi.getStreak();
      if (generation != _generation) return;
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
    lastCookedAt = DateTime.now().toUtc().toIso8601String();
    _loaded = true;
    notifyListeners();
  }

  /// Forget the signed-out account's streak.
  void clear() {
    _generation++;
    currentStreak = 0;
    longestStreak = 0;
    lastCookedAt = null;
    _loaded = false;
    notifyListeners();
  }
}
