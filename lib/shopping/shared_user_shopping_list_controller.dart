import "package:flutter/foundation.dart";

import "../sharing/sharing_models.dart";
import "shopping_list_api.dart";
import "shopping_list_models.dart";

/// Controller for viewing another user's shared shopping list
///
/// Handles loading the list and toggling items (if collaborative).
/// Provides optimistic updates for better UX.
class SharedUserShoppingListController extends ChangeNotifier {
  SharedUserShoppingListController({
    required this.shoppingListApi,
    required this.userId,
    required this.shareType,
  });

  final ShoppingListApi shoppingListApi;
  final String userId;
  final String shareType;

  SharedUserShoppingList? _list;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;

  SharedUserShoppingList? get list => _list;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  bool get canEdit => shareType == "collaborative";
  bool get isEmpty => _list == null || _list!.items.isEmpty;

  /// Load the shared shopping list
  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _list = await shoppingListApi.getUserShoppingList(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _list = null;
    } finally{
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle an item's checked state (only if collaborative)
  ///
  /// Uses optimistic update pattern - updates local state immediately,
  /// then syncs with server. Rolls back on error.
  Future<void> toggleItem(String itemId) async {
    if (!canEdit || _list == null || _isUpdating) return;

    // Find the item
    final itemIndex = _list!.items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final oldItem = _list!.items[itemIndex];
    final newCheckedState = !oldItem.isChecked;

    // Optimistic update
    final updatedItem = oldItem.copyWith(isChecked: newCheckedState);
    final updatedItems = List<ShoppingListItem>.from(_list!.items);
    updatedItems[itemIndex] = updatedItem;

    _list = SharedUserShoppingList(
      ownerId: _list!.ownerId,
      ownerUsername: _list!.ownerUsername,
      ownerDisplayName: _list!.ownerDisplayName,
      ownerAvatarUrl: _list!.ownerAvatarUrl,
      shareType: _list!.shareType,
      items: updatedItems,
    );

    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await shoppingListApi.updateCollaborativeItem(
        userId: userId,
        itemId: itemId,
        isChecked: newCheckedState,
      );
      _error = null;
    } catch (e) {
      // Rollback on error
      final rolledBackItems = List<ShoppingListItem>.from(_list!.items);
      rolledBackItems[itemIndex] = oldItem;

      _list = SharedUserShoppingList(
        ownerId: _list!.ownerId,
        ownerUsername: _list!.ownerUsername,
        ownerDisplayName: _list!.ownerDisplayName,
        ownerAvatarUrl: _list!.ownerAvatarUrl,
        shareType: _list!.shareType,
        items: rolledBackItems,
      );

      _error = e.toString();
      rethrow;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Refresh the shopping list (pull to refresh)
  Future<void> refresh() async {
    await load();
  }
}
