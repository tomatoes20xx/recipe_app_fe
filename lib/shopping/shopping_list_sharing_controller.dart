import "package:flutter/foundation.dart";

import "../sharing/sharing_models.dart";
import "shopping_list_api.dart";

/// Controller for managing shopping list sharing state
///
/// Handles loading who the shopping list is shared with, sharing/unsharing,
/// and provides optimistic updates for better UX.
class ShoppingListSharingController extends ChangeNotifier {
  ShoppingListSharingController({
    required this.shoppingListApi,
  });

  final ShoppingListApi shoppingListApi;

  List<SharedWithUser> _sharedWith = [];
  bool _isLoading = false;
  bool _isSharing = false;
  String? _error;

  List<SharedWithUser> get sharedWith => _sharedWith;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  String? get error => _error;
  int get sharedCount => _sharedWith.length;

  /// Check if shopping list is shared with a specific user
  bool isSharedWith(String userId) {
    return _sharedWith.any((user) => user.userId == userId);
  }

  /// Get share details for a specific user
  SharedWithUser? getSharedUser(String userId) {
    try {
      return _sharedWith.firstWhere((user) => user.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Load list of users who have access to the shopping list
  Future<void> loadSharedWith() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sharedWith = await shoppingListApi.getRecipeSharedWith().then((shares) {
        // Convert recipe shares to SharedWithUser objects
        // Group by user and take the latest share
        final Map<String, SharedWithUser> uniqueUsers = {};
        for (final share in shares) {
          final owner = share["owner"] as Map<String, dynamic>? ?? {};
          final userId = (owner["userId"] ?? owner["user_id"] ?? "").toString();
          if (userId.isNotEmpty && !uniqueUsers.containsKey(userId)) {
            uniqueUsers[userId] = SharedWithUser.fromJson(share);
          }
        }
        return uniqueUsers.values.toList();
      });
      _error = null;
    } catch (e) {
      _error = e.toString();
      _sharedWith = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Share shopping list with multiple users
  ///
  /// [userIds] - List of user IDs to share with
  /// [shareType] - "read_only" or "collaborative"
  ///
  /// Uses optimistic update pattern.
  Future<void> shareWith({
    required List<String> userIds,
    required String shareType,
  }) async {
    if (_isSharing || userIds.isEmpty) return;

    _isSharing = true;
    _error = null;
    notifyListeners();

    try {
      await shoppingListApi.shareRecipeIngredients(
        userIds: userIds,
        recipeIds: [], // Empty array means "all recipes"
        shareType: shareType,
      );

      // Reload to get full user details from server
      await loadSharedWith();

      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSharing = false;
      notifyListeners();
    }
  }

  /// Revoke access for a specific user
  ///
  /// Deletes all shares with this user (unified recipe-based system)
  Future<void> revokeAccess(String userId) async {
    if (_isSharing) return;

    // Find the user for potential rollback
    final userIndex = _sharedWith.indexWhere((u) => u.userId == userId);
    if (userIndex == -1) return;

    final removedUser = _sharedWith[userIndex];

    // Optimistic update
    _sharedWith = List.from(_sharedWith)..removeAt(userIndex);
    _isSharing = true;
    _error = null;
    notifyListeners();

    try {
      // Get all shares and find ones for this user
      final allShares = await shoppingListApi.getRecipeSharedWith();
      final userShares = allShares.where((share) {
        final owner = share["owner"] as Map<String, dynamic>? ?? {};
        final shareUserId = (owner["userId"] ?? owner["user_id"] ?? "").toString();
        return shareUserId == userId;
      }).toList();

      // Delete each share
      for (final share in userShares) {
        final shareId = (share["shareId"] ?? share["share_id"] ?? "").toString();
        if (shareId.isNotEmpty) {
          await shoppingListApi.revokeRecipeShare(shareId);
        }
      }

      _error = null;
    } catch (e) {
      // Rollback on error
      _sharedWith = List.from(_sharedWith)..insert(userIndex, removedUser);
      _error = e.toString();
      rethrow;
    } finally {
      _isSharing = false;
      notifyListeners();
    }
  }

  /// Refresh the shared-with list
  Future<void> refresh() async {
    await loadSharedWith();
  }
}
