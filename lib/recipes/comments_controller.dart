import "package:flutter/foundation.dart";

import "comment_models.dart";
import "recipe_api.dart";

class CommentsController extends ChangeNotifier {
  CommentsController({required this.recipeApi, required this.recipeId});

  final RecipeApi recipeApi;
  final String recipeId;

  final List<Comment> comments = [];
  bool isLoading = false;

  /// Set only when the list itself failed to load. A failed post or delete is
  /// rethrown to the caller instead, so it doesn't replace the list.
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

  /// Posts a comment and inserts it into [comments] without reloading.
  ///
  /// The POST response has no author fields, so the caller passes the signed-in
  /// user's [authorUsername] and [authorAvatarUrl]. Returns the new comment.
  Future<Comment?> addComment(
    String content, {
    String? parentId,
    required String authorUsername,
    String? authorAvatarUrl,
  }) async {
    if (content.trim().isEmpty) return null;

    final created = await recipeApi.postComment(recipeId, content, parentId: parentId);

    if (authorUsername.isEmpty) {
      // No cached profile (e.g. /me failed offline): fetch the list quietly
      // so the comment shows with the right author.
      try {
        final fresh = await recipeApi.getComments(recipeId);
        comments
          ..clear()
          ..addAll(fresh);
        notifyListeners();
      } catch (_) {}
      return null;
    }

    final comment = Comment(
      id: created.id,
      content: created.content,
      createdAt: created.createdAt,
      authorUsername: authorUsername,
      parentId: parentId,
      authorAvatarUrl: authorAvatarUrl,
      viewerIsMe: true,
    );
    comments.add(comment);
    notifyListeners();
    return comment;
  }

  /// Deletes a comment and drops it and its replies from [comments]
  /// (the backend soft-deletes the whole subtree).
  Future<void> deleteComment(String commentId) async {
    await recipeApi.deleteComment(recipeId, commentId);

    final removed = <String>{commentId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in comments) {
        if (c.parentId != null && removed.contains(c.parentId) && removed.add(c.id)) {
          grew = true;
        }
      }
    }
    comments.removeWhere((c) => removed.contains(c.id));
    notifyListeners();
  }
}
