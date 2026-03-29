import '../feed/feed_models.dart';
import '../utils/paginated_list_controller.dart';
import 'recipe_api.dart';

class SharedRecipesController extends PaginatedListController<FeedItem> {
  SharedRecipesController({required this.recipeApi});

  final RecipeApi recipeApi;

  @override
  Future<PaginatedResponse<FeedItem>> fetchPage(String? cursor) async {
    final res = await recipeApi.getSharedWithMeRecipes(limit: limit, cursor: cursor);
    final rawItems = (res['items'] as List<dynamic>? ?? []);
    return PaginatedResponse(
      items: rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      nextCursor: res['nextCursor']?.toString(),
    );
  }

  Future<void> dismissRecipe(String shareId) async {
    await recipeApi.dismissSharedRecipe(shareId);
    removeItemWhere((item) => item.shareId == shareId);
  }
}
