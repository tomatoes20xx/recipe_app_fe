import "package:flutter/foundation.dart";

import "../sharing/sharing_models.dart";
import "shopping_list_api.dart";

/// Controller for viewing shopping lists shared with the current user
///
/// Manages the list of shopping lists that others have shared with you.
class SharedShoppingListsController extends ChangeNotifier {
  SharedShoppingListsController({
    required this.shoppingListApi,
  });

  final ShoppingListApi shoppingListApi;

  List<SharedShoppingList> _lists = [];
  bool _isLoading = false;
  String? _error;

  List<SharedShoppingList> get lists => _lists;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _lists.isEmpty;

  /// Load shopping lists shared with the current user
  Future<void> loadLists() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _lists = await shoppingListApi.getSharedWithMeLists();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _lists = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the shared shopping lists (pull to refresh)
  Future<void> refresh() async {
    await loadLists();
  }
}
