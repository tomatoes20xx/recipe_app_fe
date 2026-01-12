import "package:flutter/foundation.dart";
import "feed_api.dart";
import "feed_models.dart";

class FeedController extends ChangeNotifier {
  FeedController({required this.feedApi});

  final FeedApi feedApi;

  final List<FeedItem> items = [];
  String? nextCursor;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  String scope = "global"; // or "following"
  String sort = "recent";  // or "top"
  int windowDays = 7;

  int limit = 20;

  Future<void> loadInitial() async {
    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await feedApi.getFeed(
        limit: limit,
        cursor: null,
        scope: scope,
        sort: sort,
        windowDays: windowDays,
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
      final res = await feedApi.getFeed(
        limit: limit,
        cursor: nextCursor,
        scope: scope,
        sort: sort,
        windowDays: windowDays,
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

  Future<void> setScope(String value) async {
    if (scope == value) return;
    scope = value;
    await loadInitial();
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

  // optimistic UI
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
    // rollback
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
