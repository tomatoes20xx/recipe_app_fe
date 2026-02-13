import "../api/api_client.dart";
import "shopping_list_models.dart";

class ShoppingListApi {
  ShoppingListApi(this.api);
  final ApiClient api;

  /// Get all shopping list items for the current user
  /// Optional filter: checked=true|false|all (default: all)
  Future<List<ShoppingListItem>> getItems({String? checkedFilter}) async {
    final queryParams = checkedFilter != null ? {"checked": checkedFilter} : null;
    final data = await api.get("/shopping-list", query: queryParams, auth: true);

    if (data == null) return [];

    final items = data["items"] as List<dynamic>;
    return items.map((json) => ShoppingListItem.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  /// Add multiple items to shopping list (bulk insert)
  /// Returns list of newly added items (excludes duplicates)
  Future<List<ShoppingListItem>> addItems(List<ShoppingListItem> items) async {
    final itemsJson = items.map((item) => {
      "ingredientId": item.ingredientId,
      "name": item.name,
      "quantity": item.quantity,
      "unit": item.unit,
      "recipeId": item.recipeId,
      "recipeName": item.recipeName,
      "recipeImage": item.recipeImage,
    }).toList();

    final data = await api.post(
      "/shopping-list/bulk",
      body: {"items": itemsJson},
      auth: true,
    );

    if (data == null) return [];

    final addedItems = data["items"] as List<dynamic>;
    return addedItems.map((json) => ShoppingListItem.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  /// Update a single item (toggle checked state)
  Future<ShoppingListItem?> updateItem(String itemId, {required bool isChecked}) async {
    final data = await api.patch(
      "/shopping-list/$itemId",
      body: {"isChecked": isChecked},
      auth: true,
    );

    if (data == null) return null;

    return ShoppingListItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Delete a single item
  Future<bool> deleteItem(String itemId) async {
    try {
      await api.delete("/shopping-list/$itemId", auth: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete multiple items (bulk delete)
  Future<int> deleteItems(List<String> itemIds) async {
    final data = await api.delete(
      "/shopping-list/bulk",
      body: {"ids": itemIds},
      auth: true,
    );

    if (data == null) return 0;

    return data["deletedCount"] as int? ?? 0;
  }

  /// Delete all items from a specific recipe
  Future<int> deleteItemsByRecipe(String recipeId) async {
    // Get all items first, filter by recipe, then bulk delete
    final allItems = await getItems();
    final recipeItemIds = allItems.where((item) => item.recipeId == recipeId).map((item) => item.id).toList();

    if (recipeItemIds.isEmpty) return 0;

    return await deleteItems(recipeItemIds);
  }
}
