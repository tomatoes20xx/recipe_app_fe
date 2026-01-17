import "package:flutter/foundation.dart";
import "user_api.dart";
import "user_models.dart";

class FollowersController extends ChangeNotifier {
  FollowersController({
    required this.userApi,
    required this.username,
  });

  final UserApi userApi;
  final String username;

  final List<UserSearchResult> items = [];
  String? nextCursor;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  bool isPrivate = false; // Set to true if we get 403

  int limit = 20;

  Future<void> loadInitial() async {
    if (isLoading) return;

    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    isPrivate = false;
    notifyListeners();

    try {
      final res = await userApi.getFollowers(
        username: username,
        limit: limit,
        cursor: null,
      );
      items.addAll(res.items);
      nextCursor = res.nextCursor;
    } catch (e) {
      // Check if it's a 403 (private list)
      if (e.toString().contains("403") || e.toString().contains("Forbidden")) {
        isPrivate = true;
        error = "This user's followers list is private";
      } else {
        error = e.toString();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await userApi.getFollowers(
        username: username,
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

  Future<void> refresh() async {
    await loadInitial();
  }
}
