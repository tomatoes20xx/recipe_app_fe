import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "comment_models.dart";
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

/// Tree node for nesting comments: root has parentId==null, replies have parentId set.
class _CommentNode {
  _CommentNode({required this.comment}) : children = [];
  final Comment comment;
  final List<_CommentNode> children;
}

List<_CommentNode> _buildCommentTree(List<Comment> flat) {
  final map = <String, _CommentNode>{};
  for (final c in flat) {
    map[c.id] = _CommentNode(comment: c);
  }
  final roots = <_CommentNode>[];
  for (final c in flat) {
    final node = map[c.id]!;
    if (c.parentId == null || c.parentId!.isEmpty || !map.containsKey(c.parentId)) {
      roots.add(node);
    } else {
      map[c.parentId]!.children.add(node);
    }
  }
  void sortByDate(_CommentNode n) {
    n.children.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
    for (final ch in n.children) {
      sortByDate(ch);
    }
  }
  roots.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
  for (final r in roots) {
    sortByDate(r);
  }
  return roots;
}

/// Persistent state storage for comments UI per recipe
/// Key: recipeId, Value: {collapsedIds, fullyExpandedIds, scrollPosition}
final Map<String, _CommentsUIState> _commentsUIStateCache = {};

class _CommentsUIState {
  final Set<String> collapsedIds;
  final Set<String> fullyExpandedIds;
  final double scrollPosition;
  final bool hasInitializedCollapsedState;

  _CommentsUIState({
    required this.collapsedIds,
    required this.fullyExpandedIds,
    this.scrollPosition = 0.0,
    this.hasInitializedCollapsedState = false,
  });

  _CommentsUIState copyWith({
    Set<String>? collapsedIds,
    Set<String>? fullyExpandedIds,
    double? scrollPosition,
    bool? hasInitializedCollapsedState,
  }) {
    return _CommentsUIState(
      collapsedIds: collapsedIds ?? this.collapsedIds,
      fullyExpandedIds: fullyExpandedIds ?? this.fullyExpandedIds,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      hasInitializedCollapsedState: hasInitializedCollapsedState ?? this.hasInitializedCollapsedState,
    );
  }
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
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  String? _replyingToId;
  String? _replyingToUsername;
  
  // Get or create UI state for this recipe
  _CommentsUIState get _uiState => _commentsUIStateCache.putIfAbsent(
    widget.recipeId,
    () => _CommentsUIState(
      collapsedIds: {},
      fullyExpandedIds: {},
    ),
  );
  
  Set<String> get _collapsedIds => _uiState.collapsedIds;
  Set<String> get _fullyExpandedIds => _uiState.fullyExpandedIds;
  bool get _hasInitializedCollapsedState => _uiState.hasInitializedCollapsedState;
  
  double _savedScrollPosition = 0.0;
  bool _shouldRestoreScrollPosition = false; // For post-action restore (after posting/deleting)
  bool _hasRestoredInitialScroll = false; // Track if we've restored saved scroll position on initial load

  @override
  void initState() {
    super.initState();
    widget.commentsController.addListener(_onChanged);
    // Initialize collapsed state if comments are already loaded
    _initializeCollapsedState();
    // Listen to scroll changes to save position continuously
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _updateUIState(scrollPosition: _scrollController.offset);
    }
  }

  void _initializeCollapsedState() {
    if (!_hasInitializedCollapsedState &&
        !widget.commentsController.isLoading && 
        widget.commentsController.comments.isNotEmpty) {
      // Build tree and collect all comment IDs that have replies
      final tree = _buildCommentTree(widget.commentsController.comments);
      final newCollapsedIds = <String>{};
      void collectCommentIdsWithReplies(List<_CommentNode> nodes) {
        for (final node in nodes) {
          if (node.children.isNotEmpty) {
            // Only add if not already manually expanded by user
            // If user has expanded it, it won't be in collapsedIds, so we preserve that
            if (_collapsedIds.contains(node.comment.id) || _collapsedIds.isEmpty) {
              newCollapsedIds.add(node.comment.id);
            }
            // Recursively check children
            collectCommentIdsWithReplies(node.children);
          }
        }
      }
      collectCommentIdsWithReplies(tree);
      // If collapsedIds was empty (first time), use newCollapsedIds
      // Otherwise, preserve existing state (user's manual choices)
      final finalCollapsedIds = _collapsedIds.isEmpty ? newCollapsedIds : _collapsedIds;
      _updateUIState(
        collapsedIds: finalCollapsedIds,
        hasInitializedCollapsedState: true,
      );
    }
  }

  @override
  void dispose() {
    widget.commentsController.removeListener(_onChanged);
    _scrollController.removeListener(_onScroll);
    // Save scroll position one final time before disposing
    if (_scrollController.hasClients) {
      _updateUIState(scrollPosition: _scrollController.offset);
    }
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateUIState({
    Set<String>? collapsedIds,
    Set<String>? fullyExpandedIds,
    double? scrollPosition,
    bool? hasInitializedCollapsedState,
  }) {
    _commentsUIStateCache[widget.recipeId] = _uiState.copyWith(
      collapsedIds: collapsedIds,
      fullyExpandedIds: fullyExpandedIds,
      scrollPosition: scrollPosition,
      hasInitializedCollapsedState: hasInitializedCollapsedState,
    );
  }

  void _onChanged() {
    if (mounted) {
      // Initialize collapsed state if not done yet (for cases where comments load after widget creation)
      _initializeCollapsedState();
      
      setState(() {});
      
      // Restore scroll position after posting/deleting comments
      if (_shouldRestoreScrollPosition && !widget.commentsController.isLoading) {
        _shouldRestoreScrollPosition = false;
        // Wait for the next frame to ensure the list has been rebuilt
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients && _savedScrollPosition > 0) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (_savedScrollPosition <= maxScroll) {
                _scrollController.jumpTo(_savedScrollPosition);
              } else if (maxScroll > 0) {
                _scrollController.jumpTo(maxScroll);
              }
              _updateUIState(scrollPosition: _savedScrollPosition);
            }
          });
        });
      }
    }
  }

  void _onReply(Comment c) {
    setState(() {
      _replyingToId = c.id;
      _replyingToUsername = c.authorUsername;
    });
    _focusNode.requestFocus();
  }

  void _onToggleCollapse(String commentId) {
    setState(() {
      final newCollapsedIds = Set<String>.from(_collapsedIds);
      final newFullyExpandedIds = Set<String>.from(_fullyExpandedIds);
      
      if (newCollapsedIds.contains(commentId)) {
        // Expanding: remove from collapsed and reset fully expanded state
        newCollapsedIds.remove(commentId);
        newFullyExpandedIds.remove(commentId);
      } else {
        // Collapsing: add to collapsed
        newCollapsedIds.add(commentId);
      }
      
      _updateUIState(
        collapsedIds: newCollapsedIds,
        fullyExpandedIds: newFullyExpandedIds,
      );
    });
  }

  void _onShowMoreReplies(String commentId) {
    setState(() {
      final newFullyExpandedIds = Set<String>.from(_fullyExpandedIds);
      newFullyExpandedIds.add(commentId);
      _updateUIState(fullyExpandedIds: newFullyExpandedIds);
    });
  }

  Future<void> _onDeleteComment(String commentId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment"),
        content: const Text("Are you sure you want to delete this comment? This will also delete all replies to this comment."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Save current scroll position before deleting
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
      _shouldRestoreScrollPosition = true;
    }

    try {
      await widget.commentsController.deleteComment(commentId);
      // Scroll position will be restored in _onChanged after loading completes
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  List<Widget> _buildCommentList(List<_CommentNode> nodes, int depth, {String? parentCommentId}) {
    final out = <Widget>[];
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final isLastChild = i == nodes.length - 1;
      out.add(_buildCommentBlock(n, depth, isLastChild: isLastChild, parentCommentId: parentCommentId));
      if (n.children.isNotEmpty && !_collapsedIds.contains(n.comment.id)) {
        // Limit to 10 replies unless fully expanded
        final isFullyExpanded = _fullyExpandedIds.contains(n.comment.id);
        final childrenToShow = isFullyExpanded ? n.children : n.children.take(10).toList();
        final hasMoreReplies = n.children.length > 10 && !isFullyExpanded;
        
        out.addAll(_buildCommentList(childrenToShow, depth + 1, parentCommentId: n.comment.id));
        
        // Add "Show more" button if there are more than 10 replies
        if (hasMoreReplies) {
          final remainingCount = n.children.length - 10;
          // Calculate indentation to match reply depth (same as _buildCommentBlock)
          final replyDepth = depth + 1;
          final maxDepth = 4;
          final indentPerLevel = 16.0;
          final cappedDepth = replyDepth > maxDepth ? maxDepth : replyDepth;
          final leftMargin = indentPerLevel * cappedDepth;
          
          out.add(
            Padding(
              padding: EdgeInsets.only(left: leftMargin + 10, top: 8, bottom: 8),
              child: TextButton(
                onPressed: () => _onShowMoreReplies(n.comment.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  "Show $remainingCount more ${remainingCount == 1 ? 'reply' : 'replies'}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    return out;
  }

  /// Recursively counts all descendants (replies at any depth) of a comment node
  int _countAllReplies(_CommentNode node) {
    int count = node.children.length;
    for (final child in node.children) {
      count += _countAllReplies(child);
    }
    return count;
  }

  Widget _buildCommentBlock(_CommentNode node, int depth, {String? parentCommentId, bool isLastChild = false}) {
    final c = node.comment;
    final date = formatDate(c.createdAt);
    final hasReplies = node.children.isNotEmpty;
    final isCollapsed = _collapsedIds.contains(c.id);
    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    final totalReplyCount = _countAllReplies(node);
    final replyLabel = totalReplyCount == 1 ? 'reply' : 'replies';

    // Build the comment content (without bottom padding)
    Widget commentContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildUserAvatar(context, c.authorAvatarUrl, c.authorUsername, radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                "@${c.authorUsername} • $date",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isLoggedIn)
                    TextButton(
                      onPressed: () => _onReply(c),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text("Reply", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  if (c.viewerIsMe)
                    TextButton(
                      onPressed: () => _onDeleteComment(c.id),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text("Delete", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  if (hasReplies)
                    TextButton.icon(
                      onPressed: () => _onToggleCollapse(c.id),
                      icon: Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        isCollapsed ? "Show $totalReplyCount $replyLabel" : "Hide $totalReplyCount $replyLabel",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    // Apply border and indentation for nested comments (depth >= 1)
    if (depth >= 1) {
      // Cap indentation at 4 levels (64px) to prevent content from shrinking too much
      // Use 16px per level instead of 24px for better space efficiency
      final maxDepth = 4;
      final indentPerLevel = 16.0;
      final cappedDepth = depth > maxDepth ? maxDepth : depth;
      final leftMargin = indentPerLevel * cappedDepth;
      
      // For last child: border wraps only content (ends at action buttons)
      // For other children: border wraps content + padding (extends to bottom)
      if (isLastChild) {
        // Last child: apply border to content only, then wrap in padding
        commentContent = Container(
          margin: EdgeInsets.only(left: leftMargin),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Colors.grey.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: commentContent,
        );
        // Wrap in padding for spacing between comments
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: commentContent,
        );
      } else {
        // Not last child: wrap content + padding in border container
        return Container(
          margin: EdgeInsets.only(left: leftMargin),
          padding: const EdgeInsets.only(left: 10, bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Colors.grey.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: commentContent,
        );
      }
    }
    
    // For root comments (depth 0), just wrap in padding
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: commentContent,
    );
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

    // Save current scroll position before submitting
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
      _shouldRestoreScrollPosition = true;
    }

    setState(() => _isSubmitting = true);
    final parentId = _replyingToId;

    try {
      await widget.commentsController.addComment(content, parentId: parentId);
      _commentController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToUsername = null;
      });
      widget.onCommentPosted?.call();
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure collapsed state is initialized (fallback in case initState didn't catch it)
    _initializeCollapsedState();
    
    // Restore scroll position after build if not already restored
    if (!_hasRestoredInitialScroll &&
        !widget.commentsController.isLoading && 
        widget.commentsController.comments.isNotEmpty) {
      final savedPosition = _uiState.scrollPosition;
      if (savedPosition > 0) {
        // Use SchedulerBinding to ensure this runs after the layout phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients && !_hasRestoredInitialScroll) {
              _hasRestoredInitialScroll = true;
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (savedPosition <= maxScroll) {
                _scrollController.jumpTo(savedPosition);
              } else if (maxScroll > 0) {
                _scrollController.jumpTo(maxScroll);
              }
            }
          });
        });
      }
    }
    
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = screenHeight * 0.75; // 75% of screen height

    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    final userAvatar = widget.auth?.me?["avatar_url"]?.toString();
    final username = widget.auth?.me?["username"]?.toString() ?? "";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: sheetHeight,
      padding: EdgeInsets.only(bottom: keyboardHeight),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                          )
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            children: _buildCommentList(
                              _buildCommentTree(widget.commentsController.comments),
                              0,
                            ),
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToId != null && _replyingToUsername != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              "Replying to @$_replyingToUsername",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _replyingToId = null;
                                _replyingToUsername = null;
                              }),
                              child: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
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
                            focusNode: _focusNode,
                            maxLines: null,
                            maxLength: 2000,
                            decoration: InputDecoration(
                              hintText: _replyingToId != null ? "Write a reply..." : "Write a comment...",
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
