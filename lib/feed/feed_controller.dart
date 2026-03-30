import '../constants/enums.dart';
import '../recipes/recipe_api.dart';
import '../utils/paginated_list_controller.dart';
import 'feed_api.dart';
import 'feed_models.dart' as feed_models;

class FeedController extends PaginatedListController<feed_models.FeedItem> {
  FeedController({required this.feedApi, this.recipeApi});

  final FeedApi feedApi;
  final RecipeApi? recipeApi;

  FeedScope scope = FeedScope.global;
  FeedSort sort = FeedSort.recent;
  int windowDays = 7;
  String? selectedCategory;
  PopularPeriod popularPeriod = PopularPeriod.allTime;
  int trendingDays = 7; // 1-30

  @override
  Future<void> loadInitial() async {
    await doLoadInitial();
  }

  @override
  Future<PaginatedResponse<feed_models.FeedItem>> fetchPage(String? cursor) async {
    if (scope == FeedScope.popular) {
      if (recipeApi == null) throw Exception('RecipeApi is required for popular feed');
      final res = await recipeApi!.getPopularRecipes(
        period: popularPeriod.apiValue,
        limit: limit,
        cursor: cursor,
        tags: selectedCategory != null ? [selectedCategory!] : null,
      );
      final rawItems = (res['items'] as List<dynamic>? ?? []);
      return PaginatedResponse(
        items: rawItems.map((e) => feed_models.FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        nextCursor: res['nextCursor']?.toString(),
      );
    } else if (scope == FeedScope.trending) {
      if (recipeApi == null) throw Exception('RecipeApi is required for trending feed');
      final res = await recipeApi!.getTrendingRecipes(
        days: trendingDays,
        limit: limit,
        cursor: cursor,
        tags: selectedCategory != null ? [selectedCategory!] : null,
      );
      final rawItems = (res['items'] as List<dynamic>? ?? []);
      return PaginatedResponse(
        items: rawItems.map((e) => feed_models.FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        nextCursor: res['nextCursor']?.toString(),
      );
    } else {
      final res = await feedApi.getFeed(
        limit: limit,
        cursor: cursor,
        scope: scope.apiValue,
        sort: sort.apiValue,
        windowDays: windowDays,
        tags: selectedCategory != null ? [selectedCategory!] : null,
      );
      return PaginatedResponse(items: res.items, nextCursor: res.nextCursor);
    }
  }

  Future<void> setCategory(String? value) async {
    if (selectedCategory == value) return;
    selectedCategory = value;
    await loadInitial();
  }

  Future<void> setScope(FeedScope value) async {
    if (scope == value) return;
    scope = value;
    await loadInitial();
  }

  Future<void> setPopularPeriod(PopularPeriod value) async {
    if (popularPeriod == value) return;
    popularPeriod = value;
    if (scope == FeedScope.popular) {
      await loadInitial();
    } else {
      notifyListeners();
    }
  }

  Future<void> setTrendingDays(int value) async {
    if (trendingDays == value) return;
    trendingDays = value;
    if (scope == FeedScope.trending) {
      await loadInitial();
    } else {
      notifyListeners();
    }
  }

  Future<void> setSort(FeedSort value) async {
    if (sort == value) return;
    sort = value;
    await loadInitial();
  }

  Future<void> setWindowDays(int value) async {
    if (windowDays == value) return;
    windowDays = value;
    if (sort == FeedSort.top) {
      await loadInitial();
    } else {
      notifyListeners();
    }
  }

  Future<void> toggleLike(String recipeId) async {
    final i = indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    final old = items[i];
    final nextLiked = !old.viewerHasLiked;
    updateItemAt(i, old.copyWith(viewerHasLiked: nextLiked, likes: old.likes + (nextLiked ? 1 : -1)));
    notifyListeners();
    try {
      if (nextLiked) {
        await feedApi.like(recipeId);
      } else {
        await feedApi.unlike(recipeId);
      }
    } catch (e) {
      updateItemAt(i, old);
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(String recipeId) async {
    final i = indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    final old = items[i];
    final next = !old.viewerHasBookmarked;
    updateItemAt(i, old.copyWith(viewerHasBookmarked: next, bookmarks: old.bookmarks + (next ? 1 : -1)));
    notifyListeners();
    try {
      if (next) {
        await feedApi.bookmark(recipeId);
      } else {
        await feedApi.unbookmark(recipeId);
      }
    } catch (e) {
      updateItemAt(i, old);
      error = e.toString();
      notifyListeners();
    }
  }

  void updateBookmarkState(String recipeId, bool bookmarked) {
    final i = indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    final old = items[i];
    if (old.viewerHasBookmarked == bookmarked) return;
    updateItemAt(i, old.copyWith(
      viewerHasBookmarked: bookmarked,
      bookmarks: old.bookmarks + (bookmarked ? 1 : -1),
    ));
    notifyListeners();
  }

  void updateCommentCount(String recipeId, int newCount) {
    final i = indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    updateItemAt(i, items[i].copyWith(comments: newCount));
    notifyListeners();
  }
}
