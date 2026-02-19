import "../api/api_client.dart";
import "../sharing/sharing_models.dart";
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

  // ==================== SHARING METHODS (UNIFIED RECIPE-BASED SYSTEM) ====================

  /// Share recipe ingredients from shopping list (unified sharing method)
  ///
  /// [userIds] - List of user IDs to share with (must be followers)
  /// [recipeIds] - List of recipe IDs to share ingredients from
  ///               Pass empty array [] to share ALL recipes
  /// [shareType] - "read_only" or "collaborative"
  /// [itemIds] - Optional map of recipeId -> list of itemIds to share specific items
  Future<void> shareRecipeIngredients({
    required List<String> userIds,
    required List<String> recipeIds,
    required String shareType,
    Map<String, List<String>>? itemIds,
  }) async {
    // Build shares array in new format
    final List<Map<String, dynamic>> shares;

    if (recipeIds.isEmpty) {
      // Empty array = share all recipes
      shares = [];
    } else {
      // Build shares array with optional itemIds
      shares = recipeIds.map((recipeId) {
        final share = <String, dynamic>{"recipeId": recipeId};

        // Add itemIds if specified for this recipe
        if (itemIds != null && itemIds.containsKey(recipeId)) {
          share["itemIds"] = itemIds[recipeId];
        }
        // No itemIds = share all items from this recipe

        return share;
      }).toList();
    }

    await api.post(
      "/shopping-list/share/recipes",
      body: {
        "userIds": userIds,
        "shares": shares,
        "shareType": shareType,
      },
      auth: true,
    );
  }

  /// Get recipe shopping lists shared with the current user
  ///
  /// Returns list of shared recipe shopping lists grouped by recipe
  Future<List<SharedRecipeShoppingList>> getSharedRecipeListsWithMe() async {
    final data = await api.get(
      "/shopping-list/recipes/shared-with-me",
      auth: true,
    );

    // Handle different response formats
    if (data is List) {
      final parsed = data
          .map((e) => SharedRecipeShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return parsed;
    } else if (data is Map) {
      final items = data["sharedRecipeLists"] ?? data["items"] ?? data["data"] ?? [];
      if (items is List) {
        final parsed = items
            .map((e) => SharedRecipeShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return parsed;
      }
    }

    return [];
  }

  /// Get shopping list items for a specific recipe from another user
  ///
  /// [userId] - Owner of the shopping list
  /// [recipeId] - ID of the recipe
  Future<Map<String, dynamic>> getUserRecipeShoppingList({
    required String userId,
    required String recipeId,
  }) async {
    final data = await api.get(
      "/shopping-list/user/$userId/recipe/$recipeId",
      auth: true,
    );

    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {"items": [], "shareType": "read_only"};
  }

  /// Unshare a specific recipe shopping list
  ///
  /// [shareId] - ID of the share to remove
  Future<void> revokeRecipeShare(String shareId) async {
    await api.delete(
      "/shopping-list/share/recipes/$shareId",
      auth: true,
    );
  }

  /// Unshare ALL recipes with a specific user (bulk delete)
  ///
  /// [userId] - ID of the user to revoke all shares from
  /// Returns number of shares deleted
  Future<int> revokeAllSharesWithUser(String userId) async {
    final data = await api.delete(
      "/shopping-list/share/user/$userId",
      auth: true,
    );

    if (data is Map && data.containsKey("deleted")) {
      return data["deleted"] as int? ?? 0;
    }

    return 0;
  }

  /// Get list of users who have access to specific recipes in shopping list
  ///
  /// Returns list of shares grouped by recipe
  Future<List<Map<String, dynamic>>> getRecipeSharedWith() async {
    final data = await api.get(
      "/shopping-list/recipes/shared-with",
      auth: true,
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (data is Map) {
      final items = data["shares"] ?? data["items"] ?? data["data"] ?? [];
      if (items is List) {
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    return [];
  }

  /// Update an item in a collaborative recipe shopping list
  ///
  /// [userId] - Owner of the shopping list
  /// [recipeId] - ID of the recipe
  /// [itemId] - ID of the item to update
  /// [isChecked] - New checked state
  Future<ShoppingListItem?> updateCollaborativeRecipeItem({
    required String userId,
    required String recipeId,
    required String itemId,
    required bool isChecked,
  }) async {
    final data = await api.patch(
      "/shopping-list/user/$userId/recipe/$recipeId/item/$itemId",
      body: {"isChecked": isChecked},
      auth: true,
    );

    if (data == null) return null;

    return ShoppingListItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Dismiss/remove a shared recipe list (works for both specific recipes and "all recipes" shares)
  ///
  /// [shareId] - ID of the share to dismiss
  Future<void> dismissSharedRecipeList(String shareId) async {
    await api.delete(
      "/shopping-list/shared-with-me/$shareId",
      auth: true,
    );
  }
}
