import "package:flutter/foundation.dart";
import "search_api.dart";
import "search_filters.dart";
import "search_models.dart";

class RecipeSearchController extends ChangeNotifier {
  RecipeSearchController({required this.searchApi});

  final SearchApi searchApi;

  final List<SearchResult> items = [];
  String? nextCursor;
  RecipeSearchFilters filters = RecipeSearchFilters();

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int limit = 20;

  Future<void> search({String? query, RecipeSearchFilters? filters}) async {
    // Update filters
    if (filters != null) {
      this.filters = filters;
    } else if (query != null) {
      this.filters = this.filters.copyWith(query: query);
    }

    // Validate: at least one filter or query required
    if (!this.filters.isValid) {
      items.clear();
      nextCursor = null;
      error = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await searchApi.searchRecipes(
        query: this.filters.query,
        cuisine: this.filters.cuisine,
        tags: this.filters.tags.isNotEmpty ? this.filters.tags : null,
        ingredients: this.filters.ingredients.isNotEmpty ? this.filters.ingredients : null,
        cookingTimeMin: this.filters.cookingTimeMin,
        cookingTimeMax: this.filters.cookingTimeMax,
        difficulty: this.filters.difficulty,
        limit: limit,
        cursor: null,
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

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null || !filters.isValid) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await searchApi.searchRecipes(
        query: filters.query,
        cuisine: filters.cuisine,
        tags: filters.tags.isNotEmpty ? filters.tags : null,
        ingredients: filters.ingredients.isNotEmpty ? filters.ingredients : null,
        cookingTimeMin: filters.cookingTimeMin,
        cookingTimeMax: filters.cookingTimeMax,
        difficulty: filters.difficulty,
        limit: limit,
        cursor: nextCursor,
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

  void clear() {
    items.clear();
    nextCursor = null;
    filters = RecipeSearchFilters();
    error = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  void updateFilters(RecipeSearchFilters newFilters) {
    filters = newFilters;
    notifyListeners();
  }
}
