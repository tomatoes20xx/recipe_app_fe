import "package:flutter/foundation.dart";

import "user_api.dart";

class StreakController extends ChangeNotifier {
  StreakController({required this.userApi});

  final UserApi userApi;

  int currentStreak = 0;
  int longestStreak = 0;
  String? lastCookedAt;
  bool _loaded = false;

  /// The user's current calendar date, as the server counts it (in the
  /// user's timezone). Dates here are plain calendar days stored as UTC
  /// midnights, so comparing them involves no timezone math.
  DateTime? _today;

  /// Calendar date of the latest cook, in the user's timezone.
  DateTime? _lastCookDay;

  bool get loaded => _loaded;

  /// Bumped by [clear] so a load that was in flight at sign-out is dropped.
  int _generation = 0;

  /// Today's date for the streak (see [_today]). Falls back to the UTC date,
  /// which is how servers without per-user timezones count days.
  DateTime get today => _today ?? _utcDate(DateTime.now());

  /// Days covered by [currentStreak]: the run of consecutive cook days that
  /// ends on the latest cook day (today or yesterday when the streak is live).
  Set<DateTime> get streakDays {
    final end = _lastCookDay;
    if (currentStreak <= 0 || end == null) return const {};
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
      _today = _parseDay(data["today"]);
      // Older servers send only last_cooked_at and count UTC days.
      final lastCooked = lastCookedAt == null ? null : DateTime.tryParse(lastCookedAt!);
      _lastCookDay = _parseDay(data["last_cook_day"]) ?? (lastCooked == null ? null : _utcDate(lastCooked));
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Silent — streak is non-critical
    }
  }

  void updateFromCook(int streakDays) {
    currentStreak = streakDays;
    lastCookedAt = DateTime.now().toUtc().toIso8601String();
    _lastCookDay = today;
    _loaded = true;
    notifyListeners();
  }

  /// Forget the signed-out account's streak.
  void clear() {
    _generation++;
    currentStreak = 0;
    longestStreak = 0;
    lastCookedAt = null;
    _today = null;
    _lastCookDay = null;
    _loaded = false;
    notifyListeners();
  }

  /// "YYYY-MM-DD" → that calendar day at UTC midnight.
  static DateTime? _parseDay(Object? value) {
    if (value is! String) return null;
    final parts = value.split("-");
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  static DateTime _utcDate(DateTime t) {
    final u = t.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }
}
