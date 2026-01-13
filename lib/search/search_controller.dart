import "package:flutter/foundation.dart";
import "search_api.dart";
import "search_models.dart";

class RecipeSearchController extends ChangeNotifier {
  RecipeSearchController({required this.searchApi});

  final SearchApi searchApi;

  final List<SearchResult> items = [];
  String? nextCursor;
  String? currentQuery;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int limit = 20;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      items.clear();
      nextCursor = null;
      currentQuery = null;
      error = null;
      notifyListeners();
      return;
    }

    if (query == currentQuery && items.isNotEmpty) {
      return; // Already searched for this query
    }

    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    currentQuery = query.trim();
    notifyListeners();

    try {
      final res = await searchApi.searchRecipes(
        query: currentQuery!,
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
    if (nextCursor == null || currentQuery == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await searchApi.searchRecipes(
        query: currentQuery!,
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
    currentQuery = null;
    error = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }
}
