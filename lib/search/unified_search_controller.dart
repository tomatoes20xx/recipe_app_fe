import "package:flutter/foundation.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "search_api.dart";
import "search_filters.dart";
import "search_history_storage.dart";
import "search_models.dart";

class UnifiedSearchController extends ChangeNotifier {
  UnifiedSearchController({
    required this.searchApi,
    required this.userApi,
    required this.historyStorage,
  });

  final SearchApi searchApi;
  final UserApi userApi;
  final SearchHistoryStorage historyStorage;

  String? currentQuery;
  RecipeSearchFilters recipeFilters = RecipeSearchFilters();

  final List<UserSearchResult> users = [];
  final List<SearchResult> recipes = [];

  String? usersNextCursor;
  String? recipesNextCursor;
  bool usersHasMore = false;
  bool recipesHasMore = false;

  bool isLoading = false;
  bool isLoadingMoreUsers = false;
  bool isLoadingMoreRecipes = false;
  String? error;

  List<String> recentSearches = [];

  int limit = 10;

  Future<void> loadRecentSearches() async {
    recentSearches = await historyStorage.getRecentSearches();
    notifyListeners();
  }

  Future<void> search(String query, {RecipeSearchFilters? filters, bool saveToHistory = false}) async {
    if (query.trim().isEmpty) {
      clear();
      return;
    }

    currentQuery = query.trim();
    if (filters != null) {
      recipeFilters = filters;
    }

    isLoading = true;
    error = null;
    users.clear();
    recipes.clear();
    usersNextCursor = null;
    recipesNextCursor = null;
    notifyListeners();

    try {
      final res = await searchApi.unifiedSearch(
        query: currentQuery!,
        limit: limit,
        cuisine: recipeFilters.cuisine,
        tags: recipeFilters.tags.isNotEmpty ? recipeFilters.tags : null,
        ingredients: recipeFilters.ingredients.isNotEmpty ? recipeFilters.ingredients : null,
        cookingTimeMin: recipeFilters.cookingTimeMin,
        cookingTimeMax: recipeFilters.cookingTimeMax,
        difficulty: recipeFilters.difficulty,
      );

      users.addAll(res.users.items);
      usersNextCursor = res.users.nextCursor;
      usersHasMore = res.users.hasMore;

      recipes.addAll(res.recipes.items);
      recipesNextCursor = res.recipes.nextCursor;
      recipesHasMore = res.recipes.hasMore;

      if (saveToHistory) {
        await historyStorage.addSearch(currentQuery!);
        await loadRecentSearches();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the current query to history (call when user commits a search)
  Future<void> commitCurrentQueryToHistory() async {
    if (currentQuery != null && currentQuery!.trim().isNotEmpty) {
      await historyStorage.addSearch(currentQuery!);
      await loadRecentSearches();
    }
  }

  Future<void> loadMoreUsers() async {
    if (isLoading || isLoadingMoreUsers) return;
    if (!usersHasMore || usersNextCursor == null || currentQuery == null) return;

    isLoadingMoreUsers = true;
    notifyListeners();

    try {
      final res = await searchApi.unifiedSearch(
        query: currentQuery!,
        types: ["users"],
        limit: limit,
        usersCursor: usersNextCursor,
      );

      users.addAll(res.users.items);
      usersNextCursor = res.users.nextCursor;
      usersHasMore = res.users.hasMore;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMoreUsers = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreRecipes() async {
    if (isLoading || isLoadingMoreRecipes) return;
    if (!recipesHasMore || recipesNextCursor == null || currentQuery == null) return;

    isLoadingMoreRecipes = true;
    notifyListeners();

    try {
      final res = await searchApi.unifiedSearch(
        query: currentQuery!,
        types: ["recipes"],
        limit: limit,
        cuisine: recipeFilters.cuisine,
        tags: recipeFilters.tags.isNotEmpty ? recipeFilters.tags : null,
        ingredients: recipeFilters.ingredients.isNotEmpty ? recipeFilters.ingredients : null,
        cookingTimeMin: recipeFilters.cookingTimeMin,
        cookingTimeMax: recipeFilters.cookingTimeMax,
        difficulty: recipeFilters.difficulty,
        recipesCursor: recipesNextCursor,
      );

      recipes.addAll(res.recipes.items);
      recipesNextCursor = res.recipes.nextCursor;
      recipesHasMore = res.recipes.hasMore;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMoreRecipes = false;
      notifyListeners();
    }
  }

  Future<void> updateFilters(RecipeSearchFilters filters) async {
    recipeFilters = filters;
    if (currentQuery != null && currentQuery!.isNotEmpty) {
      // Only refetch recipes with new filters
      isLoading = true;
      error = null;
      recipes.clear();
      recipesNextCursor = null;
      notifyListeners();

      try {
        final res = await searchApi.unifiedSearch(
          query: currentQuery!,
          types: ["recipes"],
          limit: limit,
          cuisine: recipeFilters.cuisine,
          tags: recipeFilters.tags.isNotEmpty ? recipeFilters.tags : null,
          ingredients: recipeFilters.ingredients.isNotEmpty ? recipeFilters.ingredients : null,
          cookingTimeMin: recipeFilters.cookingTimeMin,
          cookingTimeMax: recipeFilters.cookingTimeMax,
          difficulty: recipeFilters.difficulty,
        );

        recipes.addAll(res.recipes.items);
        recipesNextCursor = res.recipes.nextCursor;
        recipesHasMore = res.recipes.hasMore;
      } catch (e) {
        error = e.toString();
      } finally {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleFollow(String username) async {
    final i = users.indexWhere((u) => u.username == username);
    if (i < 0) return;

    final old = users[i];
    final newFollowing = !old.viewerIsFollowing;

    users[i] = old.copyWith(viewerIsFollowing: newFollowing);
    notifyListeners();

    try {
      if (newFollowing) {
        await userApi.followUser(username);
      } else {
        await userApi.unfollowUser(username);
      }
    } catch (e) {
      users[i] = old;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeFromHistory(String query) async {
    await historyStorage.removeSearch(query);
    await loadRecentSearches();
  }

  Future<void> clearHistory() async {
    await historyStorage.clearHistory();
    recentSearches.clear();
    notifyListeners();
  }

  void clear() {
    currentQuery = null;
    users.clear();
    recipes.clear();
    usersNextCursor = null;
    recipesNextCursor = null;
    usersHasMore = false;
    recipesHasMore = false;
    error = null;
    isLoading = false;
    isLoadingMoreUsers = false;
    isLoadingMoreRecipes = false;
    notifyListeners();
  }
}
