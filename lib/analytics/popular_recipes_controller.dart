import '../constants/enums.dart';
import '../feed/feed_api.dart';
import '../feed/feed_models.dart';
import '../recipes/recipe_api.dart';
import '../utils/paginated_list_controller.dart';

class PopularRecipesController extends PaginatedListController<FeedItem> {
  PopularRecipesController({required this.recipeApi, required this.feedApi});

  final RecipeApi recipeApi;
  final FeedApi feedApi;
  PopularPeriod period = PopularPeriod.allTime;

  @override
  Future<void> loadInitial() async {
    await doLoadInitial();
  }

  @override
  Future<PaginatedResponse<FeedItem>> fetchPage(String? cursor) async {
    final res = await recipeApi.getPopularRecipes(
      period: period.apiValue,
      limit: limit,
      cursor: cursor,
    );
    final rawItems = (res['items'] as List<dynamic>? ?? []);
    return PaginatedResponse(
      items: rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      nextCursor: res['nextCursor']?.toString(),
    );
  }

  Future<void> setPeriod(PopularPeriod newPeriod) async {
    if (period == newPeriod) return;
    period = newPeriod;
    await loadInitial();
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

  void updateCommentCount(String recipeId, int newCount) {
    final i = indexWhere((x) => x.id == recipeId);
    if (i < 0) return;
    updateItemAt(i, items[i].copyWith(comments: newCount));
    notifyListeners();
  }
}
