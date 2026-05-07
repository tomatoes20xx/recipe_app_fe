import "../api/api_client.dart";
import "feed_models.dart";

class FeedApi {
  FeedApi(this.api);
  final ApiClient api;

  Future<void> like(String recipeId) async {
    await api.put("/recipes/$recipeId/like", auth: true);
  }

  Future<void> unlike(String recipeId) async {
    await api.delete("/recipes/$recipeId/like", auth: true);
  }

  Future<void> bookmark(String recipeId) async {
    await api.put("/recipes/$recipeId/bookmark", auth: true);
  }

  Future<void> unbookmark(String recipeId) async {
    await api.delete("/recipes/$recipeId/bookmark", auth: true);
  }

  Future<FeedResponse> getFeed({
    required int limit,
    String? cursor,
    required String scope,
    required String sort,
    required int windowDays,
    List<String>? tags,
  }) async {
    final query = <String, String>{
      "limit": limit.toString(),
      "scope": scope,
      "sort": sort,
      "windowDays": windowDays.toString(),
      if (cursor != null) "cursor": cursor,
      if (tags != null && tags.isNotEmpty) "tags": tags.join(","),
    };

    final data = await api.get("/feed", query: query, auth: true);
    return FeedResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> postSeenRecipes(List<String> recipeIds) async {
    await api.post("/feed/seen", body: {"recipe_ids": recipeIds}, auth: true);
  }
}
