import "../api/api_client.dart";
import "search_models.dart";

class SearchApi {
  SearchApi(this.api);
  final ApiClient api;

  Future<SearchResponse> searchRecipes({
    String? query,
    String? cuisine,
    List<String>? tags,
    List<String>? ingredients,
    int? cookingTimeMin,
    int? cookingTimeMax,
    String? difficulty,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    // Add query if provided
    if (query != null && query.trim().isNotEmpty) {
      queryParams["q"] = query.trim();
    }

    // Add filters
    if (cuisine != null && cuisine.trim().isNotEmpty) {
      queryParams["cuisine"] = cuisine.trim();
    }

    if (tags != null && tags.isNotEmpty) {
      queryParams["tags"] = tags.join(",");
    }

    if (ingredients != null && ingredients.isNotEmpty) {
      queryParams["ingredients"] = ingredients.join(",");
    }

    if (cookingTimeMin != null) {
      queryParams["cooking_time_min"] = cookingTimeMin.toString();
    }

    if (cookingTimeMax != null) {
      queryParams["cooking_time_max"] = cookingTimeMax.toString();
    }

    if (difficulty != null && difficulty.isNotEmpty) {
      queryParams["difficulty"] = difficulty;
    }

    final data = await api.get("/search/recipes", query: queryParams, auth: true);
    return SearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<UnifiedSearchResponse> unifiedSearch({
    required String query,
    List<String> types = const ["recipes", "users"],
    int limit = 10,
    String? cuisine,
    List<String>? tags,
    List<String>? ingredients,
    int? cookingTimeMin,
    int? cookingTimeMax,
    String? difficulty,
    String? recipesCursor,
    String? usersCursor,
  }) async {
    final queryParams = <String, String>{
      "q": query.trim(),
      "types": types.join(","),
      "limit": limit.toString(),
    };

    if (cuisine != null && cuisine.trim().isNotEmpty) {
      queryParams["cuisine"] = cuisine.trim();
    }

    if (tags != null && tags.isNotEmpty) {
      queryParams["tags"] = tags.join(",");
    }

    if (ingredients != null && ingredients.isNotEmpty) {
      queryParams["ingredients"] = ingredients.join(",");
    }

    if (cookingTimeMin != null) {
      queryParams["cooking_time_min"] = cookingTimeMin.toString();
    }

    if (cookingTimeMax != null) {
      queryParams["cooking_time_max"] = cookingTimeMax.toString();
    }

    if (difficulty != null && difficulty.isNotEmpty) {
      queryParams["difficulty"] = difficulty;
    }

    if (recipesCursor != null) {
      queryParams["recipes_cursor"] = recipesCursor;
    }

    if (usersCursor != null) {
      queryParams["users_cursor"] = usersCursor;
    }

    final data = await api.get("/search", query: queryParams, auth: true);
    return UnifiedSearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
