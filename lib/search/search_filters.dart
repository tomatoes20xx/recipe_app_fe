/// Model for recipe search filters
class RecipeSearchFilters {
  final String? query;
  final String? cuisine;
  final List<String> tags;
  final List<String> ingredients;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty; // 'easy', 'medium', 'hard'

  RecipeSearchFilters({
    this.query,
    this.cuisine,
    this.tags = const [],
    this.ingredients = const [],
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
  });

  /// Check if any filter is active
  bool get hasActiveFilters {
    return query != null && query!.isNotEmpty ||
        cuisine != null && cuisine!.isNotEmpty ||
        tags.isNotEmpty ||
        ingredients.isNotEmpty ||
        cookingTimeMin != null ||
        cookingTimeMax != null ||
        difficulty != null;
  }

  /// Check if filters are valid (at least one filter or query)
  bool get isValid {
    return hasActiveFilters;
  }

  RecipeSearchFilters copyWith({
    String? query,
    String? cuisine,
    List<String>? tags,
    List<String>? ingredients,
    int? cookingTimeMin,
    int? cookingTimeMax,
    String? difficulty,
    bool clearQuery = false,
    bool clearCuisine = false,
    bool clearTags = false,
    bool clearIngredients = false,
    bool clearCookingTime = false,
    bool clearDifficulty = false,
  }) {
    return RecipeSearchFilters(
      query: clearQuery ? null : (query ?? this.query),
      cuisine: clearCuisine ? null : (cuisine ?? this.cuisine),
      tags: clearTags ? const [] : (tags ?? this.tags),
      ingredients: clearIngredients ? const [] : (ingredients ?? this.ingredients),
      cookingTimeMin: clearCookingTime ? null : (cookingTimeMin ?? this.cookingTimeMin),
      cookingTimeMax: clearCookingTime ? null : (cookingTimeMax ?? this.cookingTimeMax),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
    );
  }

  /// Clear all filters
  RecipeSearchFilters clearAll() {
    return RecipeSearchFilters();
  }

  /// Convert filters to query parameters
  Map<String, String> toQueryParams() {
    final params = <String, String>{};

    if (query != null && query!.trim().isNotEmpty) {
      params["q"] = query!.trim();
    }

    if (cuisine != null && cuisine!.trim().isNotEmpty) {
      params["cuisine"] = cuisine!.trim();
    }

    if (tags.isNotEmpty) {
      // Use comma-separated format: tags=pasta,dinner
      params["tags"] = tags.join(",");
    }

    if (ingredients.isNotEmpty) {
      // Use comma-separated format: ingredients=tomato,cheese
      params["ingredients"] = ingredients.join(",");
    }

    if (cookingTimeMin != null) {
      params["cooking_time_min"] = cookingTimeMin!.toString();
    }

    if (cookingTimeMax != null) {
      params["cooking_time_max"] = cookingTimeMax!.toString();
    }

    if (difficulty != null && difficulty!.isNotEmpty) {
      params["difficulty"] = difficulty!;
    }

    return params;
  }
}
