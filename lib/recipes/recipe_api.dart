import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;

import "../api/api_client.dart";
import "../sharing/sharing_models.dart";
import "comment_models.dart";
import "recipe_detail_models.dart";

class RecipeApi {
  RecipeApi(this.api);
  final ApiClient api;

  Future<RecipeDetail?> getRecipeDetail(String recipeId) async {
    final data = await api.get("/recipes/$recipeId", auth: true);
    if (data == null) return null;
    return RecipeDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<RecipeDetail> createRecipe({
    required String title,
    String? description,
    String? cuisine,
    List<String> tags = const [],
    int? cookingTimeMin,
    int? cookingTimeMax,
    String? difficulty,
    required List<Map<String, dynamic>> ingredients,
    required List<Map<String, dynamic>> steps,
    List<File>? images,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description?.trim();
    final trimmedCuisine = cuisine?.trim();
    final tagsList = tags.isEmpty ? [] : tags;

    // Always use multipart upload for consistency across devices
    // This ensures the same request format works on both emulator and real devices
    // Send recipe fields directly as form fields
    // Arrays/objects need to be JSON-encoded strings
    final fields = <String, String>{
      "title": trimmedTitle,
      "tags": jsonEncode(tagsList),
      "ingredients": jsonEncode(ingredients),
      "steps": jsonEncode(steps),
    };
    
    // Add optional fields only if they have values
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      fields["description"] = trimmedDescription;
    }
    if (trimmedCuisine != null && trimmedCuisine.isNotEmpty) {
      fields["cuisine"] = trimmedCuisine;
    }
    // Only add cooking time fields if they are valid positive integers
    if (cookingTimeMin != null && cookingTimeMin >= 0) {
      fields["cooking_time_min"] = cookingTimeMin.toString();
    }
    if (cookingTimeMax != null && cookingTimeMax >= 0) {
      fields["cooking_time_max"] = cookingTimeMax.toString();
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      fields["difficulty"] = difficulty;
    }
    
    // Create multipart files (empty list if no images)
    final multipartFiles = <http.MultipartFile>[];
    if (images != null && images.isNotEmpty) {
      for (final file in images) {
        final length = await file.length();
        final filename = file.path.split('/').last;
        final contentType = _getContentTypeFromFilename(filename);
        
        multipartFiles.add(
          http.MultipartFile(
            'images',
            file.openRead(),
            length,
            filename: filename,
            contentType: http.MediaType.parse(contentType),
          ),
        );
      }
    }
    
    final data = await api.postMultipart(
      "/recipes",
      fields: fields,
      files: multipartFiles,
      auth: true,
    );
    
    return await _handleRecipeCreationResponse(data);
  }

  Future<String> updateRecipe({
    required String recipeId,
    String? title,
    String? description,
    String? cuisine,
    List<String>? tags,
    int? cookingTimeMin,
    int? cookingTimeMax,
    String? difficulty,
    List<Map<String, dynamic>>? ingredients,
    List<Map<String, dynamic>>? steps,
  }) async {
    final body = <String, dynamic>{};
    
    // Only include fields that are provided (partial update)
    if (title != null) {
      body["title"] = title.trim();
    }
    if (description != null) {
      body["description"] = description.trim();
    }
    if (cuisine != null) {
      body["cuisine"] = cuisine.trim();
    }
      if (tags != null) {
        body["tags"] = tags;
      }
      if (cookingTimeMin != null) {
        body["cooking_time_min"] = cookingTimeMin;
      }
      if (cookingTimeMax != null) {
        body["cooking_time_max"] = cookingTimeMax;
      }
      if (difficulty != null && difficulty.isNotEmpty) {
        body["difficulty"] = difficulty;
      }
      if (ingredients != null) {
        body["ingredients"] = ingredients;
      }
      if (steps != null) {
        body["steps"] = steps;
      }
    
    if (body.isEmpty) {
      throw Exception("At least one field must be provided for update");
    }
    
    final data = await api.patch(
      "/recipes/$recipeId",
      body: body,
      auth: true,
    );
    
    // API returns { id: recipeId }
    if (data is Map && data.containsKey("id")) {
      return data["id"].toString();
    }
    if (data is String) {
      return data;
    }
    throw Exception("Unexpected response format from update recipe");
  }

  Future<void> deleteRecipe(String recipeId) async {
    await api.delete("/recipes/$recipeId", auth: true);
    // DELETE returns 204 No Content, so no response body to parse
  }

  Future<RecipeDetail> _handleRecipeCreationResponse(dynamic data) async {
    if (data == null) {
      throw Exception("API returned null response");
    }
    
    // Handle different response types
    if (data is String) {
      // API returned just an ID string, fetch full recipe
      final recipe = await getRecipeDetail(data);
      if (recipe == null) {
        throw Exception("Failed to fetch recipe after creation");
      }
      return recipe;
    }
    
    if (data is! Map) {
      throw Exception("API returned unexpected type: ${data.runtimeType}, expected Map or String");
    }
    
    final dataMap = Map<String, dynamic>.from(data);
    
    // If response has an 'id' but not full recipe data, fetch it
    if (dataMap.containsKey('id') && !dataMap.containsKey('title')) {
      final recipeId = dataMap['id'].toString();
      final recipe = await getRecipeDetail(recipeId);
      if (recipe == null) {
        throw Exception("Failed to fetch recipe after creation");
      }
      return recipe;
    }
    
    return RecipeDetail.fromJson(dataMap);
  }

  String _getContentTypeFromFilename(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default to JPEG
    }
  }

  Future<List<Comment>> getComments(String recipeId) async {
    final data = await api.get("/recipes/$recipeId/comments", auth: true);
    if (data == null) return [];
    
    // API returns nested structure: { items: [{ id, body, replies: [...] }], nextCursor: "..." }
    List<dynamic> topLevelComments;
    if (data is Map && data.containsKey("items")) {
      topLevelComments = data["items"] as List? ?? [];
    } else if (data is List) {
      // Fallback: handle direct list response
      topLevelComments = data;
    } else {
      return [];
    }
    
    // Recursively flatten the nested structure: extract replies at any depth and set their parent_id
    final flatComments = <Comment>[];
    
    // Recursive function to process a comment and all its nested replies
    void processComment(Map<String, dynamic> commentMap, String? parentId) {
      // Create the comment with the given parent_id
      final commentData = Map<String, dynamic>.from(commentMap);
      if (parentId != null) {
        commentData["parent_id"] = parentId;
      }
      final comment = Comment.fromJson(commentData);
      flatComments.add(comment);
      
      // Recursively process replies
      final replies = commentMap["replies"] as List?;
      if (replies != null && replies.isNotEmpty) {
        for (final replyData in replies) {
          final replyMap = Map<String, dynamic>.from(replyData as Map);
          // Recursively process this reply with the current comment as its parent
          processComment(replyMap, comment.id);
        }
      }
    }
    
    // Process all top-level comments (parent_id = null)
    for (final item in topLevelComments) {
      final itemMap = Map<String, dynamic>.from(item as Map);
      processComment(itemMap, null);
    }
    
    return flatComments;
  }

  Future<Comment> postComment(String recipeId, String content, {String? parentId}) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw Exception("Comment cannot be empty");
    }
    if (trimmedContent.length > 2000) {
      throw Exception("Comment cannot exceed 2000 characters");
    }
    final body = <String, dynamic>{"body": trimmedContent};
    if (parentId != null && parentId.isNotEmpty) {
      body["parent_id"] = parentId;
    }
    final data = await api.post(
      "/recipes/$recipeId/comments",
      body: body,
      auth: true,
    );
    if (data == null) {
      throw Exception("API returned null response");
    }
    return Comment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteComment(String recipeId, String commentId) async {
    await api.delete("/recipes/$recipeId/comments/$commentId", auth: true);
    // DELETE returns 204 No Content, so no response body to parse
  }

  Future<void> like(String recipeId) async {
    await api.put("/recipes/$recipeId/like", auth: true);
  }

  Future<void> unlike(String recipeId) async {
    await api.delete("/recipes/$recipeId/like", auth: true);
  }

  Future<void> bookmark(String recipeId) async {
    await api.put("/recipes/$recipeId/bookmark", auth: true);
  }

  Future<void> unbookmark(String recipeId) async {
    await api.delete("/recipes/$recipeId/bookmark", auth: true);
  }

  /// Add an image to a recipe
  Future<void> addRecipeImage(String recipeId, File image) async {
    final length = await image.length();
    final filename = image.path.split('/').last;
    final contentType = _getContentTypeFromFilename(filename);

    final multipartFile = http.MultipartFile(
      'image',
      image.openRead(),
      length,
      filename: filename,
      contentType: http.MediaType.parse(contentType),
    );

    await api.postMultipart(
      "/recipes/$recipeId/images",
      fields: {}, // No additional fields needed for image upload
      files: [multipartFile],
      auth: true,
    );
  }

  /// Delete an image from a recipe
  Future<void> deleteRecipeImage(String recipeId, String imageId) async {
    await api.delete("/recipes/$recipeId/images/$imageId", auth: true);
  }

  /// Reorder recipe images
  Future<void> reorderRecipeImages(String recipeId, List<String> imageIds) async {
    await api.patch(
      "/recipes/$recipeId/images/reorder",
      body: {"imageIds": imageIds},
      auth: true,
    );
  }

  /// Get popular recipes
  /// 
  /// [period] - Time period: "all_time", "30d", or "7d"
  /// [limit] - Number of items per page (default: 20)
  /// [cursor] - Pagination cursor
  Future<Map<String, dynamic>> getPopularRecipes({
    String period = "all_time",
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      "period": period,
      if (cursor != null) "cursor": cursor,
    };

    // auth: true so viewer flags work; if no token, header won't be set
    final data = await api.get("/recipes/popular", query: queryParams, auth: true);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Get trending recipes
  ///
  /// [days] - Number of days to look back (1-30, default: 7)
  /// [limit] - Number of items per page (default: 20)
  /// [cursor] - Pagination cursor
  Future<Map<String, dynamic>> getTrendingRecipes({
    int days = 7,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      "days": days.toString(),
      if (cursor != null) "cursor": cursor,
    };

    // auth: true so viewer flags work; if no token, header won't be set
    final data = await api.get("/recipes/trending", query: queryParams, auth: true);
    return Map<String, dynamic>.from(data as Map);
  }

  // ==================== SHARING METHODS ====================

  /// Share a recipe with followers
  ///
  /// [recipeId] - ID of the recipe to share
  /// [userIds] - List of user IDs to share with (must be followers)
  Future<void> shareRecipe(String recipeId, List<String> userIds) async {
    await api.post(
      "/recipes/$recipeId/share",
      body: {"userIds": userIds},
      auth: true,
    );
  }

  /// Unshare a recipe from a specific user
  ///
  /// [recipeId] - ID of the recipe
  /// [userId] - User ID to remove access from
  Future<void> unshareRecipe(String recipeId, String userId) async {
    await api.delete(
      "/recipes/$recipeId/share/$userId",
      auth: true,
    );
  }

  /// Get recipes shared with the current user
  ///
  /// [limit] - Number of items per page (default: 20)
  /// [cursor] - Pagination cursor for next page
  /// Returns FeedResponse format (items list, nextCursor, etc.)
  Future<Map<String, dynamic>> getSharedWithMeRecipes({
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
    };

    final data = await api.get(
      "/recipes/shared-with-me",
      query: queryParams,
      auth: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Get list of users who have access to a recipe
  ///
  /// [recipeId] - ID of the recipe
  /// Returns list of SharedWithUser objects
  Future<List<SharedWithUser>> getRecipeSharedWith(String recipeId) async {
    final data = await api.get(
      "/recipes/$recipeId/shared-with",
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

  /// Dismiss/remove a recipe that was shared with you
  ///
  /// [recipeId] - ID of the shared recipe to dismiss
  Future<void> dismissSharedRecipe(String recipeId) async {
    await api.delete(
      "/recipes/shared-with-me/$recipeId",
      auth: true,
    );
  }
}
