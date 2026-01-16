import "package:flutter/foundation.dart";
import "../feed/feed_models.dart";
import "user_api.dart";

class UserRecipesController extends ChangeNotifier {
  UserRecipesController({
    required this.userApi,
    required this.username,
  });

  final UserApi userApi;
  final String username;

  final List<FeedItem> items = [];
  String? nextCursor;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int limit = 20;

  Future<void> loadInitial() async {
    if (isLoading) return;

    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await userApi.getUserRecipes(
        username: username,
        limit: limit,
        cursor: null,
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

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await userApi.getUserRecipes(
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
