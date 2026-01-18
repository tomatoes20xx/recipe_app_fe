import "package:flutter/foundation.dart";
import "feed_api.dart";
import "feed_models.dart" as feed_models;
import "../recipes/recipe_api.dart";

class FeedController extends ChangeNotifier {
  FeedController({
    required this.feedApi,
    this.recipeApi,
  });

  final FeedApi feedApi;
  final RecipeApi? recipeApi;

  final List<feed_models.FeedItem> items = [];
  String? nextCursor;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  String scope = "global"; // "global", "following", "popular", "trending"
  String sort = "recent";  // or "top"
  int windowDays = 7;
  
  // For popular recipes
  String popularPeriod = "all_time"; // "all_time", "30d", "7d"
  // For trending recipes
  int trendingDays = 7; // 1-30

  int limit = 20;

  Future<void> loadInitial() async {
    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      if (scope == "popular") {
        if (recipeApi == null) {
          throw Exception("RecipeApi is required for popular feed");
        }
        final res = await recipeApi!.getPopularRecipes(
          period: popularPeriod,
          limit: limit,
          cursor: null,
        );
        final rawItems = (res["items"] as List<dynamic>? ?? []);
        items.addAll(
          rawItems.map((e) => feed_models.FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
        nextCursor = res["nextCursor"]?.toString();
      } else if (scope == "trending") {
        if (recipeApi == null) {
          throw Exception("RecipeApi is required for trending feed");
        }
        final res = await recipeApi!.getTrendingRecipes(
          days: trendingDays,
          limit: limit,
          cursor: null,
        );
        final rawItems = (res["items"] as List<dynamic>? ?? []);
        items.addAll(
          rawItems.map((e) => feed_models.FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
        nextCursor = res["nextCursor"]?.toString();
      } else {
        final res = await feedApi.getFeed(
          limit: limit,
          cursor: null,
          scope: scope,
          sort: sort,
          windowDays: windowDays,
        );
        items.addAll(res.items);
        nextCursor = res.nextCursor;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      if (scope == "popular") {
        if (recipeApi == null) {
          throw Exception("RecipeApi is required for popular feed");
        }
        final res = await recipeApi!.getPopularRecipes(
          period: popularPeriod,
          limit: limit,
          cursor: nextCursor,
        );
        final rawItems = (res["items"] as List<dynamic>? ?? []);
        items.addAll(
          rawItems.map((e) => feed_models.FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
        nextCursor = res["nextCursor"]?.toString();
      } else if (scope == "trending") {
        if (recipeApi == null) {
          throw Exception("RecipeApi is required for trending feed");
        }
        final res = await recipeApi!.getTrendingRecipes(
          days: trendingDays,
          limit: limit,
          cursor: nextCursor,
        );
        final rawItems = (res["items"] as List<dynamic>? ?? []);
        items.addAll(
          rawItems.map((e) => feed_models.FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
        nextCursor = res["nextCursor"]?.toString();
      } else {
        final res = await feedApi.getFeed(
          limit: limit,
          cursor: nextCursor,
          scope: scope,
          sort: sort,
          windowDays: windowDays,
        );
        items.addAll(res.items);
        nextCursor = res.nextCursor;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> setScope(String value) async {
    if (scope == value) return;
    scope = value;
    await loadInitial();
  }

  Future<void> setPopularPeriod(String value) async {
    if (popularPeriod == value) return;
    popularPeriod = value;
    if (scope == "popular") {
      await loadInitial();
    } else {
      notifyListeners();
    }
  }

  Future<void> setTrendingDays(int value) async {
    if (trendingDays == value) return;
    trendingDays = value;
    if (scope == "trending") {
      await loadInitial();
    } else {
      notifyListeners();
    }
  }

  Future<void> setSort(String value) async {
    if (sort == value) return;
    sort = value;
    await loadInitial();
  }

  Future<void> setWindowDays(int value) async {
    if (windowDays == value) return;
    windowDays = value;
    if (sort == "top") {
      await loadInitial();
    } else {
      notifyListeners();
    }
  }

  Future<void> toggleLike(String recipeId) async {
    final i = items.indexWhere((x) => x.id == recipeId);
    if (i < 0) return;

    final old = items[i];
    final nextLiked = !old.viewerHasLiked;

    // Optimistic UI update
    items[i] = old.copyWith(
      viewerHasLiked: nextLiked,
      likes: old.likes + (nextLiked ? 1 : -1),
    );
    notifyListeners();

    try {
      if (nextLiked) {
        await feedApi.like(recipeId);
      } else {
        await feedApi.unlike(recipeId);
      }
    } catch (e) {
      // Rollback on error
      items[i] = old;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(String recipeId) async {
    final i = items.indexWhere((x) => x.id == recipeId);
    if (i < 0) return;

    final old = items[i];
    final next = !old.viewerHasBookmarked;

    // Optimistic UI update
    items[i] = old.copyWith(
      viewerHasBookmarked: next,
      bookmarks: old.bookmarks + (next ? 1 : -1),
    );
    notifyListeners();

    try {
      if (next) {
        await feedApi.bookmark(recipeId);
      } else {
        await feedApi.unbookmark(recipeId);
      }
    } catch (e) {
      // Rollback on error
      items[i] = old;
      error = e.toString();
      notifyListeners();
    }
  }

  void updateCommentCount(String recipeId, int newCount) {
    final i = items.indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    
    final old = items[i];
    items[i] = old.copyWith(comments: newCount);
    notifyListeners();
  }
}
