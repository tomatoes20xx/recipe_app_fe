import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../utils/ui_utils.dart";
import "comments_controller.dart";
import "recipe_api.dart";

/// Shows a bottom sheet with comments for a recipe.
/// [onCommentPosted] is called when the user successfully posts a comment, so the
/// parent can update its comment count (e.g. recipe detail overlay or feed card).
Future<void> showCommentsBottomSheet({
  required BuildContext context,
  required String recipeId,
  required ApiClient apiClient,
  AuthController? auth,
  VoidCallback? onCommentPosted,
}) async {
  final recipeApi = RecipeApi(apiClient);
  final commentsController = CommentsController(recipeApi: recipeApi, recipeId: recipeId);
  
  // Load comments before showing the sheet
  await commentsController.load();

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CommentsBottomSheet(
      recipeId: recipeId,
      commentsController: commentsController,
      auth: auth,
      onCommentPosted: onCommentPosted,
    ),
  );
}

class _CommentsBottomSheet extends StatefulWidget {
  const _CommentsBottomSheet({
    required this.recipeId,
    required this.commentsController,
    this.auth,
    this.onCommentPosted,
  });

  final String recipeId;
  final CommentsController commentsController;
  final AuthController? auth;
  final VoidCallback? onCommentPosted;

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    widget.commentsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.commentsController.removeListener(_onChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to comment")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.commentsController.addComment(content);
      _commentController.clear();
      widget.onCommentPosted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post comment: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.75; // 75% of screen height

    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    final userAvatar = widget.auth?.me?["avatar_url"]?.toString();
    final username = widget.auth?.me?["username"]?.toString() ?? "";

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  "Comments (${widget.commentsController.comments.length})",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Comments list
          Expanded(
            child: widget.commentsController.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.commentsController.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Error loading comments",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => widget.commentsController.load(),
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : widget.commentsController.comments.isEmpty
                        ? Center(
                            child: Text(
                              "No comments yet. Be the first to comment!",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: widget.commentsController.comments.length,
                            itemBuilder: (context, index) {
                              final comment = widget.commentsController.comments[index];
                              final date = formatDate(comment.createdAt);
                              return ListTile(
                                leading: buildUserAvatar(
                                  context,
                                  null, // Comment model doesn't have avatar URL
                                  comment.authorUsername,
                                  radius: 20,
                                ),
                                title: Text(
                                  comment.content,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                subtitle: Text(
                                  "@${comment.authorUsername} • $date",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                dense: false,
                              );
                            },
                          ),
          ),
          // Comment input
          if (isLoggedIn) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    buildUserAvatar(
                      context,
                      userAvatar,
                      username,
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: null,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          hintText: "Write a comment...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          counterText: "",
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSubmitting ? null : _submitComment,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      tooltip: "Post comment",
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Log in to comment",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
