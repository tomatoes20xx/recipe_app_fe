import "package:flutter/foundation.dart";

import "comment_models.dart";
import "recipe_api.dart";

class CommentsController extends ChangeNotifier {
  CommentsController({required this.recipeApi, required this.recipeId});

  final RecipeApi recipeApi;
  final String recipeId;

  final List<Comment> comments = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      comments.clear();
      final loadedComments = await recipeApi.getComments(recipeId);
      comments.addAll(loadedComments);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> addComment(String content, {String? parentId}) async {
    if (content.trim().isEmpty) return;

    try {
      await recipeApi.postComment(recipeId, content, parentId: parentId);
      // Always reload comments after posting to get full data with author info
      await load();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await recipeApi.deleteComment(recipeId, commentId);
      // Reload comments after deletion to reflect changes
      await load();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
