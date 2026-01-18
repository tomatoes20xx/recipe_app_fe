import "package:flutter/foundation.dart";
import "analytics_api.dart";
import "analytics_models.dart";

class AnalyticsStatsController extends ChangeNotifier {
  AnalyticsStatsController({required this.analyticsApi});

  final AnalyticsApi analyticsApi;

  AnalyticsStats? stats;
  bool isLoading = false;
  String? error;

  /// Load statistics
  Future<void> loadStats() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      stats = await analyticsApi.getStats();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh statistics
  Future<void> refresh() async {
    await loadStats();
  }

  /// Clear all data
  void clear() {
    stats = null;
    error = null;
    isLoading = false;
    notifyListeners();
  }
}
