import "../api/api_client.dart";
import "../users/user_models.dart";
import "collection_models.dart";

class CollectionApi {
  CollectionApi(this.api);
  final ApiClient api;

  /// GET /collections
  Future<CollectionsResponse> getCollections({
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };
    final data = await api.get("/collections", query: query, auth: true);
    return CollectionsResponse.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  /// POST /collections
  Future<Collection> createCollection(String name) async {
    final data = await api.post(
      "/collections",
      body: {"name": name.trim()},
      auth: true,
    );
    return Collection.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// PATCH /collections/:id
  Future<Collection> renameCollection(String id, String name) async {
    final data = await api.patch(
      "/collections/$id",
      body: {"name": name.trim()},
      auth: true,
    );
    return Collection.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// DELETE /collections/:id
  /// Recipes become regular bookmarks (reappear in /users/me/bookmarks).
  Future<void> deleteCollection(String id) async {
    await api.delete("/collections/$id", auth: true);
  }

  /// GET /collections/:id/recipes
  Future<UserRecipesResponse> getCollectionRecipes({
    required String collectionId,
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };
    final data = await api.get(
      "/collections/$collectionId/recipes",
      query: query,
      auth: true,
    );
    return UserRecipesResponse.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  /// PUT /collections/:id/recipes/:recipeId
  /// Adds/moves recipe to collection. Auto-bookmarks if not already.
  Future<void> addRecipe(String collectionId, String recipeId) async {
    await api.put(
        "/collections/$collectionId/recipes/$recipeId", auth: true);
  }

  /// PATCH /collections/:id/recipes/:recipeId/move-to-bookmarks
  /// Moves recipe from collection back to regular bookmarks.
  Future<void> moveToBookmarks(String collectionId, String recipeId) async {
    await api.patch(
        "/collections/$collectionId/recipes/$recipeId/move-to-bookmarks",
        auth: true);
  }

  /// DELETE /collections/:id/recipes/:recipeId
  /// Fully unbookmarks the recipe (viewer_has_bookmarked becomes false).
  Future<void> removeRecipe(String collectionId, String recipeId) async {
    await api.delete(
        "/collections/$collectionId/recipes/$recipeId", auth: true);
  }

  /// GET /recipes/:id/collections
  /// Returns which collection this recipe belongs to, or null.
  Future<RecipeCollectionInfo?> getRecipeCollection(String recipeId) async {
    final data = await api.get(
        "/recipes/$recipeId/collections", auth: true);
    if (data is Map && data["collection"] != null) {
      return RecipeCollectionInfo.fromJson(
          Map<String, dynamic>.from(data["collection"] as Map));
    }
    return null;
  }
}
