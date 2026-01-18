import "../api/api_client.dart";
import "analytics_models.dart";

class AnalyticsApi {
  AnalyticsApi(this.api);
  final ApiClient api;

  /// Track a custom analytics event
  /// 
  /// [eventType] - Type of event (e.g., "search", "share", "filter_applied")
  /// [recipeId] - Optional recipe ID if event is recipe-related
  /// [metadata] - Optional additional data as key-value pairs
  Future<void> trackEvent({
    required String eventType,
    String? recipeId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = <String, dynamic>{
        "event_type": eventType,
        if (recipeId != null) "recipe_id": recipeId,
        if (metadata != null) "metadata": metadata,
      };

      await api.post("/analytics/track", body: body, auth: false);
      // Fire-and-forget: don't await or show errors to user
    } catch (e) {
      // Silently fail - analytics tracking should not affect user experience
    }
  }

  /// Track a recipe view (convenience method)
  /// Note: GET /recipes/:id already auto-tracks views, but this can be used
  /// for explicit tracking if needed
  Future<void> trackRecipeView(String recipeId) async {
    try {
      await api.post("/recipes/$recipeId/view", auth: false);
      // Fire-and-forget: don't await or show errors to user
    } catch (e) {
      // Silently fail - analytics tracking should not affect user experience
    }
  }

  /// Track a search query
  Future<void> trackSearch({
    required String query,
    Map<String, dynamic>? filters,
  }) async {
    await trackEvent(
      eventType: "search",
      metadata: {
        "query": query,
        if (filters != null) "filters": filters,
      },
    );
  }

  /// Track filter usage
  Future<void> trackFilterApplied(Map<String, dynamic> filters) async {
    await trackEvent(
      eventType: "filter_applied",
      metadata: filters,
    );
  }

  /// Track share event
  Future<void> trackShare(String recipeId, {String? platform}) async {
    await trackEvent(
      eventType: "share",
      recipeId: recipeId,
      metadata: platform != null ? {"platform": platform} : null,
    );
  }

  /// Get aggregated analytics statistics
  /// Requires authentication
  Future<AnalyticsStats> getStats() async {
    final data = await api.get("/analytics/stats", auth: true);
    return AnalyticsStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get paginated analytics events
  /// Requires authentication
  /// 
  /// [limit] - Number of items per page (1-100, default: 50)
  /// [cursor] - Pagination cursor
  /// [eventType] - Optional filter by event type
  /// [recipeId] - Optional filter by recipe ID
  /// [userId] - Optional filter by user ID
  Future<AnalyticsEventsResponse> getEvents({
    int limit = 50,
    String? cursor,
    String? eventType,
    String? recipeId,
    String? userId,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
      if (eventType != null) "event_type": eventType,
      if (recipeId != null) "recipe_id": recipeId,
      if (userId != null) "user_id": userId,
    };

    final data = await api.get("/analytics/events", query: queryParams, auth: true);
    return AnalyticsEventsResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
