import '../feed/feed_models.dart';
import '../utils/paginated_list_controller.dart';
import 'collection_api.dart';

class CollectionDetailController extends PaginatedListController<FeedItem> {
  CollectionDetailController({
    required this.collectionApi,
    required this.collectionId,
  });

  final CollectionApi collectionApi;
  final String collectionId;

  @override
  Future<PaginatedResponse<FeedItem>> fetchPage(String? cursor) async {
    final res = await collectionApi.getCollectionRecipes(
      collectionId: collectionId,
      limit: limit,
      cursor: cursor,
    );
    return PaginatedResponse(items: res.items, nextCursor: res.nextCursor);
  }

  Future<void> removeRecipe(String recipeId) async {
    await collectionApi.removeRecipe(collectionId, recipeId);
    removeItemWhere((item) => item.id == recipeId);
  }
}
