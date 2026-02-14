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

  // ==================== SHARING METHODS ====================

  /// Share shopping list with followers
  ///
  /// [userIds] - List of user IDs to share with (must be followers)
  /// [shareType] - "read_only" or "collaborative"
  Future<void> shareShoppingList({
    required List<String> userIds,
    required String shareType,
  }) async {
    await api.post(
      "/shopping-list/share",
      body: {
        "userIds": userIds,
        "shareType": shareType,
      },
      auth: true,
    );
  }

  /// Revoke shopping list access from a specific user
  ///
  /// [userId] - User ID to remove access from
  Future<void> revokeShoppingListAccess(String userId) async {
    await api.delete(
      "/shopping-list/share/$userId",
      auth: true,
    );
  }

  /// Get shopping lists shared with the current user
  ///
  /// Returns list of SharedShoppingList objects
  Future<List<SharedShoppingList>> getSharedWithMeLists() async {
    final data = await api.get(
      "/shopping-list/shared-with-me",
      auth: true,
    );

    // Handle different response formats
    if (data is List) {
      return data
          .map((e) => SharedShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (data is Map) {
      // Response is wrapped - check common keys
      final items = data["sharedLists"] ?? data["items"] ?? data["data"] ?? [];
      if (items is List) {
        return items
            .map((e) => SharedShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }

    return [];
  }

  /// Get list of users who have access to the current user's shopping list
  ///
  /// Returns list of SharedWithUser objects
  Future<List<SharedWithUser>> getShoppingListSharedWith() async {
    final data = await api.get(
      "/shopping-list/shared-with",
      auth: true,
    );

    // Handle different response formats safely
    if (data is List) {
      return data
          .map((e) => SharedWithUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (data is Map) {
      final items = data["items"] ?? data["data"] ?? [];
      if (items is List) {
        return items
            .map((e) => SharedWithUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }

    return [];
  }

  /// Get another user's shopping list (if shared with you)
  ///
  /// [userId] - ID of the user whose list to fetch
  /// Returns SharedUserShoppingList with all items
  Future<SharedUserShoppingList> getUserShoppingList(String userId) async {
    final data = await api.get(
      "/shopping-list/user/$userId",
      auth: true,
    );

    if (data is Map<String, dynamic>) {
      return SharedUserShoppingList.fromJson(data);
    } else if (data is Map) {
      return SharedUserShoppingList.fromJson(Map<String, dynamic>.from(data));
    } else {
      throw Exception("Unexpected response format for getUserShoppingList: ${data.runtimeType}");
    }
  }

  /// Update an item in a collaborative shopping list
  ///
  /// [userId] - Owner of the shopping list
  /// [itemId] - ID of the item to update
  /// [isChecked] - New checked state
  Future<ShoppingListItem?> updateCollaborativeItem({
    required String userId,
    required String itemId,
    required bool isChecked,
  }) async {
    final data = await api.patch(
      "/shopping-list/user/$userId/item/$itemId",
      body: {"isChecked": isChecked},
      auth: true,
    );

    if (data == null) return null;

    return ShoppingListItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ==================== RECIPE-SPECIFIC SHARING METHODS ====================

  /// Share specific recipe ingredients from shopping list
  ///
  /// [userIds] - List of user IDs to share with (must be followers)
  /// [recipeIds] - List of recipe IDs to share ingredients from
  /// [shareType] - "read_only" or "collaborative"
  Future<void> shareRecipeIngredients({
    required List<String> userIds,
    required List<String> recipeIds,
    required String shareType,
  }) async {
    await api.post(
      "/shopping-list/share/recipes",
      body: {
        "userIds": userIds,
        "recipeIds": recipeIds,
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
      return data
          .map((e) => SharedRecipeShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (data is Map) {
      final items = data["sharedRecipeLists"] ?? data["items"] ?? data["data"] ?? [];
      if (items is List) {
        return items
            .map((e) => SharedRecipeShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
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
}
