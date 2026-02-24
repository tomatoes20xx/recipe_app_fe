import "dart:convert";

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

    final cursorMap = <String, String>{};
    if (recipesCursor != null) {
      cursorMap["recipes"] = recipesCursor;
    }
    if (usersCursor != null) {
      cursorMap["users"] = usersCursor;
    }
    if (cursorMap.isNotEmpty) {
      queryParams["cursor"] = jsonEncode(cursorMap);
    }

    final data = await api.get("/search", query: queryParams, auth: true);
    return UnifiedSearchResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Search for recipes that can be made with the given ingredients
  Future<SearchResponse> searchByIngredients({
    required List<String> haveIngredients,
    int matchThreshold = 70,
    String? cuisine,
    int? cookingTimeMin,
    int? cookingTimeMax,
    String? difficulty,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "types": "recipes",
      "have_ingredients": haveIngredients.join(","),
      "match_threshold": matchThreshold.toString(),
      "limit": limit.toString(),
    };

    if (cursor != null) {
      queryParams["cursor"] = jsonEncode({"recipes": cursor});
    }

    if (cuisine != null && cuisine.trim().isNotEmpty) {
      queryParams["cuisine"] = cuisine.trim();
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

    final data = await api.get("/search", query: queryParams, auth: true);
    final results = data["results"] as Map<String, dynamic>? ?? {};
    final recipesData = results["recipes"] as Map<String, dynamic>? ?? {};

    return SearchResponse(
      items: (recipesData["items"] as List<dynamic>? ?? [])
          .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      nextCursor: recipesData["nextCursor"]?.toString(),
    );
  }
}
