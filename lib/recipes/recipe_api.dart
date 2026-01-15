import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;

import "../api/api_client.dart";
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
    
    // API returns: { items: [...], nextCursor: "..." }
    List<dynamic> commentsList;
    if (data is Map && data.containsKey("items")) {
      commentsList = data["items"] as List? ?? [];
    } else if (data is List) {
      // Fallback: handle direct list response
      commentsList = data;
    } else {
      return [];
    }
    
    return commentsList
        .map((e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Comment> postComment(String recipeId, String content) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw Exception("Comment cannot be empty");
    }
    if (trimmedContent.length > 2000) {
      throw Exception("Comment cannot exceed 2000 characters");
    }
    
    final data = await api.post(
      "/recipes/$recipeId/comments",
      body: {"body": trimmedContent},
      auth: true,
    );
    if (data == null) {
      throw Exception("API returned null response");
    }
    return Comment.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
