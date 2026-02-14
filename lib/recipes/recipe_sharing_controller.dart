import "package:flutter/foundation.dart";

import "../sharing/sharing_models.dart";
import "recipe_api.dart";

/// Controller for managing recipe sharing state
///
/// Handles loading who a recipe is shared with, sharing/unsharing,
/// and provides optimistic updates for better UX.
class RecipeSharingController extends ChangeNotifier {
  RecipeSharingController({
    required this.recipeApi,
    required this.recipeId,
  });

  final RecipeApi recipeApi;
  final String recipeId;

  List<SharedWithUser> _sharedWith = [];
  bool _isLoading = false;
  bool _isSharing = false;
  String? _error;

  List<SharedWithUser> get sharedWith => _sharedWith;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  String? get error => _error;
  int get sharedCount => _sharedWith.length;

  /// Check if recipe is shared with a specific user
  bool isSharedWith(String userId) {
    return _sharedWith.any((user) => user.userId == userId);
  }

  /// Load list of users who have access to this recipe
  Future<void> loadSharedWith() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sharedWith = await recipeApi.getRecipeSharedWith(recipeId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _sharedWith = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Share recipe with multiple users
  ///
  /// Uses optimistic update - adds users to local list immediately,
  /// then syncs with server. Rolls back on error.
  Future<void> shareWith(List<String> userIds) async {
    if (_isSharing || userIds.isEmpty) return;

    _isSharing = true;
    _error = null;
    notifyListeners();

    try {
      await recipeApi.shareRecipe(recipeId, userIds);

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

  /// Remove access for a specific user
  ///
  /// Uses optimistic update - removes user from local list immediately,
  /// then syncs with server. Rolls back on error.
  Future<void> unshareWith(String userId) async {
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
      await recipeApi.unshareRecipe(recipeId, userId);
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
