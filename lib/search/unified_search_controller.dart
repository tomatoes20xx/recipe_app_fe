import "package:flutter/foundation.dart";
import "package:recipe_app_fe/analytics/analytics_service.dart";
import "package:recipe_app_fe/constants/enums.dart";
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

  /// The query the backend actually searched for, when it corrected a typo.
  String? correctedQuery;

  /// True when no recipe matched every word and these are partial matches.
  bool relaxedResults = false;

  List<String> recentSearches = [];

  int limit = 10;

  // Bumped whenever the recipe or user results are replaced (new search, filter change,
  // clear). A response that arrives for an older generation is dropped, so it can't mix
  // into newer results.
  int _recipesGen = 0;
  int _usersGen = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadRecentSearches() async {
    recentSearches = await historyStorage.getRecentSearches();
    _notify();
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

    final recipesGen = ++_recipesGen;
    final usersGen = ++_usersGen;
    isLoading = true;
    isLoadingMoreUsers = false;
    isLoadingMoreRecipes = false;
    error = null;
    correctedQuery = null;
    relaxedResults = false;
    users.clear();
    recipes.clear();
    usersNextCursor = null;
    recipesNextCursor = null;
    _notify();

    try {
      final res = await searchApi.unifiedSearch(
        query: currentQuery!,
        limit: limit,
        cuisine: recipeFilters.cuisine,
        tags: recipeFilters.tags.isNotEmpty ? recipeFilters.tags : null,
        ingredients: recipeFilters.ingredients.isNotEmpty ? recipeFilters.ingredients : null,
        cookingTimeMin: recipeFilters.cookingTimeMin,
        cookingTimeMax: recipeFilters.cookingTimeMax,
        difficulty: recipeFilters.difficulty?.apiValue,
      );

      if (usersGen == _usersGen) {
        users.addAll(res.users.items);
        usersNextCursor = res.users.nextCursor;
        usersHasMore = res.users.hasMore;
      }

      if (recipesGen == _recipesGen) {
        recipes.addAll(res.recipes.items);
        recipesNextCursor = res.recipes.nextCursor;
        recipesHasMore = res.recipes.hasMore;
        correctedQuery = res.recipes.correctedQuery;
        relaxedResults = res.recipes.relaxed;
      }

      if (saveToHistory && usersGen == _usersGen) {
        await historyStorage.addSearch(currentQuery!);
        await loadRecentSearches();
      }
    } catch (e) {
      if (recipesGen == _recipesGen) error = e.toString();
    } finally {
      // A newer search, filter change or clear owns the loading state now.
      if (recipesGen == _recipesGen) isLoading = false;
      _notify();
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

    final gen = _usersGen;
    isLoadingMoreUsers = true;
    _notify();

    try {
      final res = await searchApi.unifiedSearch(
        query: currentQuery!,
        types: ["users"],
        limit: limit,
        usersCursor: usersNextCursor,
      );
      if (gen != _usersGen) return;

      users.addAll(res.users.items);
      usersNextCursor = res.users.nextCursor;
      usersHasMore = res.users.hasMore;
    } catch (e) {
      if (gen == _usersGen) error = e.toString();
    } finally {
      if (gen == _usersGen) isLoadingMoreUsers = false;
      _notify();
    }
  }

  Future<void> loadMoreRecipes() async {
    if (isLoading || isLoadingMoreRecipes) return;
    if (!recipesHasMore || recipesNextCursor == null || currentQuery == null) return;

    final gen = _recipesGen;
    isLoadingMoreRecipes = true;
    _notify();

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
        difficulty: recipeFilters.difficulty?.apiValue,
        recipesCursor: recipesNextCursor,
      );
      if (gen != _recipesGen) return;

      recipes.addAll(res.recipes.items);
      recipesNextCursor = res.recipes.nextCursor;
      recipesHasMore = res.recipes.hasMore;
    } catch (e) {
      if (gen == _recipesGen) error = e.toString();
    } finally {
      if (gen == _recipesGen) isLoadingMoreRecipes = false;
      _notify();
    }
  }

  Future<void> updateFilters(RecipeSearchFilters filters) async {
    recipeFilters = filters;
    if (currentQuery == null || currentQuery!.isEmpty) return;

    // Only refetch recipes with new filters
    final gen = ++_recipesGen;
    isLoading = true;
    isLoadingMoreRecipes = false;
    error = null;
    correctedQuery = null;
    relaxedResults = false;
    recipes.clear();
    recipesNextCursor = null;
    _notify();

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
        difficulty: recipeFilters.difficulty?.apiValue,
      );
      if (gen != _recipesGen) return;

      recipes.addAll(res.recipes.items);
      recipesNextCursor = res.recipes.nextCursor;
      recipesHasMore = res.recipes.hasMore;
      correctedQuery = res.recipes.correctedQuery;
      relaxedResults = res.recipes.relaxed;
    } catch (e) {
      if (gen == _recipesGen) error = e.toString();
    } finally {
      if (gen == _recipesGen) isLoading = false;
      _notify();
    }
  }

  Future<void> toggleFollow(String username) async {
    final i = users.indexWhere((u) => u.username == username);
    if (i < 0) return;

    final old = users[i];
    final newFollowing = !old.viewerIsFollowing;

    users[i] = old.copyWith(viewerIsFollowing: newFollowing);
    _notify();

    try {
      if (newFollowing) {
        await userApi.followUser(username);
        AnalyticsService().logFollow(username);
      } else {
        await userApi.unfollowUser(username);
        AnalyticsService().logUnfollow(username);
      }
    } catch (e) {
      // The list may have been replaced by a new search in the meantime.
      final j = users.indexWhere((u) => u.username == username);
      if (j >= 0) users[j] = old;
      error = e.toString();
      _notify();
    }
  }

  Future<void> removeFromHistory(String query) async {
    await historyStorage.removeSearch(query);
    await loadRecentSearches();
  }

  Future<void> clearHistory() async {
    await historyStorage.clearHistory();
    recentSearches.clear();
    _notify();
  }

  void clear() {
    _recipesGen++;
    _usersGen++;
    currentQuery = null;
    users.clear();
    recipes.clear();
    usersNextCursor = null;
    recipesNextCursor = null;
    usersHasMore = false;
    recipesHasMore = false;
    error = null;
    correctedQuery = null;
    relaxedResults = false;
    isLoading = false;
    isLoadingMoreUsers = false;
    isLoadingMoreRecipes = false;
    _notify();
  }
}
