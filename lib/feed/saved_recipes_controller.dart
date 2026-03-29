import '../feed/feed_models.dart';
import '../users/user_api.dart';
import '../utils/paginated_list_controller.dart';

class SavedRecipesController extends PaginatedListController<FeedItem> {
  SavedRecipesController({required this.userApi});

  final UserApi userApi;

  @override
  Future<PaginatedResponse<FeedItem>> fetchPage(String? cursor) async {
    final res = await userApi.getBookmarkedRecipes(limit: limit, cursor: cursor);
    return PaginatedResponse(items: res.items, nextCursor: res.nextCursor);
  }

  void removeRecipe(String recipeId) {
    removeItemWhere((item) => item.id == recipeId);
  }
}
