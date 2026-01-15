import "package:flutter/foundation.dart";
import "user_api.dart";
import "user_models.dart";

class UserSearchController extends ChangeNotifier {
  UserSearchController({required this.userApi});

  final UserApi userApi;

  final List<UserSearchResult> items = [];
  String? nextCursor;
  String? currentQuery;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int limit = 20;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clear();
      return;
    }

    currentQuery = query.trim();
    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await userApi.searchUsers(
        query: currentQuery!,
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
    if (nextCursor == null || currentQuery == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await userApi.searchUsers(
        query: currentQuery!,
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

  void clear() {
    currentQuery = null;
    items.clear();
    nextCursor = null;
    error = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> toggleFollow(String username) async {
    final i = items.indexWhere((x) => x.username == username);
    if (i < 0) return;

    final old = items[i];
    final nextFollowing = !old.viewerIsFollowing;

    // Optimistic UI update
    items[i] = old.copyWith(viewerIsFollowing: nextFollowing);
    notifyListeners();

    try {
      if (nextFollowing) {
        await userApi.followUser(username);
      } else {
        await userApi.unfollowUser(username);
      }
    } catch (e) {
      // Rollback on error
      items[i] = old;
      error = e.toString();
      notifyListeners();
    }
  }
}
