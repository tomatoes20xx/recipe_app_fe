import "package:flutter/foundation.dart";

import "../sharing/sharing_models.dart";
import "shopping_list_api.dart";

/// Represents a grouped view of shares from one user
class UserShares {
  final String ownerId;
  final String ownerUsername;
  final String? ownerDisplayName;
  final String? ownerAvatarUrl;
  final DateTime latestSharedAt;
  final int totalItems;
  final List<SharedRecipeShoppingList> shares;

  UserShares({
    required this.ownerId,
    required this.ownerUsername,
    this.ownerDisplayName,
    this.ownerAvatarUrl,
    required this.latestSharedAt,
    required this.totalItems,
    required this.shares,
  });

  String get shareType => shares.first.shareType;
  bool get isCollaborative => shareType == "collaborative";
}

/// Controller for viewing shopping lists shared with the current user
///
/// Uses the unified recipe-based sharing system.
/// Groups shares by user - one entry per user who has shared with you.
class SharedShoppingListsController extends ChangeNotifier {
  SharedShoppingListsController({
    required this.shoppingListApi,
  });

  final ShoppingListApi shoppingListApi;

  List<SharedRecipeShoppingList> _allShares = [];
  List<UserShares> _groupedShares = [];
  bool _isLoading = false;
  String? _error;

  List<UserShares> get lists => _groupedShares;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _groupedShares.isEmpty;

  /// Load shopping lists shared with the current user
  Future<void> loadLists() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allShares = await shoppingListApi.getSharedRecipeListsWithMe();
      _groupSharesByUser();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _allShares = [];
      _groupedShares = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Group shares by owner user ID
  void _groupSharesByUser() {
    final Map<String, List<SharedRecipeShoppingList>> grouped = {};

    for (final share in _allShares) {
      grouped.putIfAbsent(share.ownerId, () => []).add(share);
    }

    _groupedShares = grouped.entries.map((entry) {
      final shares = entry.value;
      // Sort by date descending to get the latest
      shares.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));

      final totalItems = shares.fold(0, (sum, share) => sum + share.totalItems);

      return UserShares(
        ownerId: entry.key,
        ownerUsername: shares.first.ownerUsername,
        ownerDisplayName: shares.first.ownerDisplayName,
        ownerAvatarUrl: shares.first.ownerAvatarUrl,
        latestSharedAt: shares.first.sharedAt,
        totalItems: totalItems,
        shares: shares,
      );
    }).toList();

    // Sort by latest share date descending
    _groupedShares.sort((a, b) => b.latestSharedAt.compareTo(a.latestSharedAt));
  }

  /// Refresh the shared shopping lists (pull to refresh)
  Future<void> refresh() async {
    await loadLists();
  }

  /// Dismiss a specific share by its ID
  Future<void> dismissShare(String shareId) async {
    try {
      await shoppingListApi.dismissSharedRecipeList(shareId);
      // Remove from local list
      _allShares.removeWhere((share) => share.shareId == shareId);
      _groupSharesByUser();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Dismiss all shares from a specific user
  Future<void> dismissAllFromUser(String ownerId) async {
    try {
      final userShares = _allShares.where((share) => share.ownerId == ownerId).toList();

      // Delete all shares from this user
      for (final share in userShares) {
        await shoppingListApi.dismissSharedRecipeList(share.shareId);
      }

      // Remove from local list
      _allShares.removeWhere((share) => share.ownerId == ownerId);
      _groupSharesByUser();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all shares from a specific user
  List<SharedRecipeShoppingList> getSharesFromUser(String ownerId) {
    return _allShares.where((share) => share.ownerId == ownerId).toList();
  }

  /// Notify listeners (for optimistic updates from UI)
  void notifyUpdate() {
    notifyListeners();
  }
}
