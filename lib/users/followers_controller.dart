import '../api/api_client.dart';
import '../utils/paginated_list_controller.dart';
import 'user_api.dart';
import 'user_models.dart';

class FollowersController extends PaginatedListController<UserSearchResult> {
  FollowersController({required this.userApi, required this.username});

  final UserApi userApi;
  final String username;
  bool isPrivate = false;

  @override
  Future<void> loadInitial() async {
    isPrivate = false;
    await super.loadInitial();
  }

  @override
  Future<PaginatedResponse<UserSearchResult>> fetchPage(String? cursor) async {
    final res = await userApi.getFollowers(
      username: username,
      limit: limit,
      cursor: cursor,
    );
    return PaginatedResponse(items: res.items, nextCursor: res.nextCursor);
  }

  @override
  void onFetchError(Object e) {
    if (e is ApiException && e.statusCode == 403) {
      isPrivate = true;
      error = 'followersListPrivate';
    } else {
      super.onFetchError(e);
    }
  }
}
