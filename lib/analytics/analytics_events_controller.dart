import "package:flutter/foundation.dart";
import "analytics_api.dart";
import "analytics_models.dart";

class AnalyticsEventsController extends ChangeNotifier {
  AnalyticsEventsController({required this.analyticsApi});

  final AnalyticsApi analyticsApi;

  final List<AnalyticsEvent> items = [];
  String? nextCursor;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  String? eventTypeFilter;
  String? recipeIdFilter;
  String? userIdFilter;

  int limit = 50;

  /// Load initial events
  Future<void> loadInitial({
    String? eventType,
    String? recipeId,
    String? userId,
  }) async {
    eventTypeFilter = eventType;
    recipeIdFilter = recipeId;
    userIdFilter = userId;

    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await analyticsApi.getEvents(
        limit: limit,
        cursor: null,
        eventType: eventType,
        recipeId: recipeId,
        userId: userId,
      );

      items.addAll(res.items);
      nextCursor = res.nextCursor;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Load more events (pagination)
  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await analyticsApi.getEvents(
        limit: limit,
        cursor: nextCursor,
        eventType: eventTypeFilter,
        recipeId: recipeIdFilter,
        userId: userIdFilter,
      );

      items.addAll(res.items);
      nextCursor = res.nextCursor;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh events
  Future<void> refresh() async {
    await loadInitial(
      eventType: eventTypeFilter,
      recipeId: recipeIdFilter,
      userId: userIdFilter,
    );
  }

  /// Clear all data
  void clear() {
    items.clear();
    nextCursor = null;
    error = null;
    isLoading = false;
    isLoadingMore = false;
    eventTypeFilter = null;
    recipeIdFilter = null;
    userIdFilter = null;
    notifyListeners();
  }
}
