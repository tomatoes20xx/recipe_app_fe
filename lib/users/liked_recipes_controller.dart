import '../feed/feed_models.dart';
import '../utils/paginated_list_controller.dart';
import 'user_api.dart';

class LikedRecipesController extends PaginatedListController<FeedItem> {
  LikedRecipesController({required this.userApi});

  final UserApi userApi;

  @override
  Future<PaginatedResponse<FeedItem>> fetchPage(String? cursor) async {
    final res = await userApi.getLikedRecipes(limit: limit, cursor: cursor);
    return PaginatedResponse(items: res.items, nextCursor: res.nextCursor);
  }
}
