import "package:flutter/foundation.dart";
import "../feed/feed_models.dart";
import "../feed/feed_api.dart";
import "../recipes/recipe_api.dart";

class PopularRecipesController extends ChangeNotifier {
  PopularRecipesController({
    required this.recipeApi,
    required this.feedApi,
  });

  final RecipeApi recipeApi;
  final FeedApi feedApi;

  final List<FeedItem> items = [];
  String? nextCursor;
  String period = "all_time"; // "all_time", "30d", "7d"

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int limit = 20;

  /// Load initial popular recipes
  Future<void> loadInitial({String? periodOverride}) async {
    final selectedPeriod = periodOverride ?? period;
    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await recipeApi.getPopularRecipes(
        period: selectedPeriod,
        limit: limit,
        cursor: null,
      );
      
      // Parse response (same structure as feed endpoint)
      final rawItems = (res["items"] as List<dynamic>? ?? []);
      items.addAll(
        rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
      nextCursor = res["nextCursor"]?.toString();
      
      if (periodOverride != null) {
        period = periodOverride;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Load more popular recipes (pagination)
  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await recipeApi.getPopularRecipes(
        period: period,
        limit: limit,
        cursor: nextCursor,
      );
      
      // Parse response (same structure as feed endpoint)
      final rawItems = (res["items"] as List<dynamic>? ?? []);
      items.addAll(
        rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
      nextCursor = res["nextCursor"]?.toString();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh popular recipes
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Change period and reload
  Future<void> setPeriod(String newPeriod) async {
    if (period == newPeriod) return;
    await loadInitial(periodOverride: newPeriod);
  }

  /// Toggle like for a recipe
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

  /// Toggle bookmark for a recipe
  Future<void> toggleBookmark(String recipeId) async {
    final i = items.indexWhere((x) => x.id == recipeId);
    if (i < 0) return;

    final old = items[i];
    final next = !old.viewerHasBookmarked;

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

  /// Update comment count for a recipe
  void updateCommentCount(String recipeId, int newCount) {
    final i = items.indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    
    final old = items[i];
    items[i] = old.copyWith(comments: newCount);
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    items.clear();
    nextCursor = null;
    error = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }
}
