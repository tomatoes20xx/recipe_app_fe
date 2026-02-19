import "package:flutter/foundation.dart";

import "../feed/feed_models.dart";
import "recipe_api.dart";

/// Controller for viewing recipes shared with the current user
///
/// Manages a paginated feed of recipes that others have shared with you.
/// Follows the same pattern as FeedController.
class SharedRecipesController extends ChangeNotifier {
  SharedRecipesController({
    required this.recipeApi,
  });

  final RecipeApi recipeApi;

  final List<FeedItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _nextCursor;
  bool _hasMore = true;
  String? _error;

  List<FeedItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// Load the first page of shared recipes
  Future<void> loadInitial() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _items.clear();
    _nextCursor = null;
    _hasMore = true;
    notifyListeners();

    try {
      final res = await recipeApi.getSharedWithMeRecipes(
        limit: 20,
        cursor: null,
      );

      final rawItems = (res["items"] as List<dynamic>? ?? []);
      _items.addAll(
        rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );

      _nextCursor = res["nextCursor"]?.toString();
      _hasMore = _nextCursor != null;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load the next page of shared recipes
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore || _nextCursor == null) return;

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final res = await recipeApi.getSharedWithMeRecipes(
        limit: 20,
        cursor: _nextCursor,
      );

      final rawItems = (res["items"] as List<dynamic>? ?? []);
      _items.addAll(
        rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );

      _nextCursor = res["nextCursor"]?.toString();
      _hasMore = _nextCursor != null;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh the shared recipes feed (pull to refresh)
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Dismiss a shared recipe (remove from your view)
  Future<void> dismissRecipe(String shareId) async {
    try {
      await recipeApi.dismissSharedRecipe(shareId);
      // Remove from local list
      _items.removeWhere((item) => item.shareId == shareId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
