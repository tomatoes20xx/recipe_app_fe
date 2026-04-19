import '../feed/feed_models.dart';
import '../users/user_api.dart';
import '../utils/paginated_list_controller.dart';

class SavedRecipesController extends PaginatedListController<FeedItem> {
  SavedRecipesController({required this.userApi});

  final UserApi userApi;

  String? searchQuery;
  String sort = 'newest';

  /// Updates search/sort params and reloads from page 1.
  Future<void> setParams({String? query, String? newSort}) async {
    searchQuery = (query?.isEmpty ?? true) ? null : query;
    if (newSort != null) sort = newSort;
    await doLoadInitial();
  }

  @override
  Future<PaginatedResponse<FeedItem>> fetchPage(String? cursor) async {
    final res = await userApi.getBookmarkedRecipes(
      limit: limit,
      cursor: cursor,
      q: searchQuery,
      sort: sort,
    );
    return PaginatedResponse(items: res.items, nextCursor: res.nextCursor);
  }

  void removeRecipe(String recipeId) {
    removeItemWhere((item) => item.id == recipeId);
  }
}
