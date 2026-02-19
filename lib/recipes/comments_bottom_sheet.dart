import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../reports/report_bottom_sheet.dart";
import "../reports/report_models.dart";
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

/// Colored thread lines per nesting depth for visual hierarchy
const _threadColors = [
  Color(0xFF5B9BD5), // Blue
  Color(0xFF70BF73), // Green
  Color(0xFFE8944A), // Orange
  Color(0xFFB07CC6), // Purple
];

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
  bool _hasText = false;
  String? _replyingToId;
  String? _replyingToUsername;
  final Set<String> _showFlaggedComments = {}; // Track which flagged comments user wants to see

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
  bool _shouldRestoreScrollPosition = false;
  bool _hasRestoredInitialScroll = false;

  @override
  void initState() {
    super.initState();
    widget.commentsController.addListener(_onChanged);
    _initializeCollapsedState();
    _scrollController.addListener(_onScroll);
    _commentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _commentController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
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
      final tree = _buildCommentTree(widget.commentsController.comments);
      final newCollapsedIds = <String>{};
      void collectCommentIdsWithReplies(List<_CommentNode> nodes) {
        for (final node in nodes) {
          if (node.children.isNotEmpty) {
            if (_collapsedIds.contains(node.comment.id) || _collapsedIds.isEmpty) {
              newCollapsedIds.add(node.comment.id);
            }
            collectCommentIdsWithReplies(node.children);
          }
        }
      }
      collectCommentIdsWithReplies(tree);
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
    _commentController.removeListener(_onTextChanged);
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
      _initializeCollapsedState();

      setState(() {});

      if (_shouldRestoreScrollPosition && !widget.commentsController.isLoading) {
        _shouldRestoreScrollPosition = false;
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
    HapticFeedback.lightImpact();
    setState(() {
      _replyingToId = c.id;
      _replyingToUsername = c.authorUsername;
    });
    _focusNode.requestFocus();
  }

  void _onToggleCollapse(String commentId) {
    HapticFeedback.selectionClick();
    setState(() {
      final newCollapsedIds = Set<String>.from(_collapsedIds);
      final newFullyExpandedIds = Set<String>.from(_fullyExpandedIds);

      if (newCollapsedIds.contains(commentId)) {
        newCollapsedIds.remove(commentId);
        newFullyExpandedIds.remove(commentId);
      } else {
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
    HapticFeedback.mediumImpact();
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(localizations?.deleteCommentTitle ?? "Delete comment?"),
        content: Text(localizations?.deleteCommentMessage ?? "This will also delete all replies to this comment."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(localizations?.delete ?? "Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
      _shouldRestoreScrollPosition = true;
    }

    try {
      await widget.commentsController.deleteComment(commentId);
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _onReportComment(String commentId) async {
    HapticFeedback.lightImpact();

    if (!(widget.auth?.isLoggedIn ?? false)) {
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showError(context, localizations?.pleaseLogInToReportComments ?? "Please log in to report comments");
      return;
    }

    await showReportBottomSheet(
      context: context,
      targetType: ReportTargetType.comment,
      targetId: commentId,
      apiClient: widget.commentsController.recipeApi.api,
    );
    // Success feedback is already shown in the bottom sheet
    // No additional action needed since backend is idempotent
  }

  int _countAllReplies(_CommentNode node) {
    int count = node.children.length;
    for (final child in node.children) {
      count += _countAllReplies(child);
    }
    return count;
  }

  List<Widget> _buildCommentList(List<_CommentNode> nodes, int depth, {String? parentCommentId}) {
    final out = <Widget>[];
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final isLastChild = i == nodes.length - 1;
      out.add(_buildCommentBlock(n, depth, isLastChild: isLastChild, parentCommentId: parentCommentId));

      // Build children with animated expand/collapse
      final hasReplies = n.children.isNotEmpty;
      final isCollapsed = _collapsedIds.contains(n.comment.id);

      if (hasReplies) {
        final isFullyExpanded = _fullyExpandedIds.contains(n.comment.id);
        final childrenToShow = isFullyExpanded ? n.children : n.children.take(10).toList();
        final hasMoreReplies = n.children.length > 10 && !isFullyExpanded;

        out.add(
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildCommentList(childrenToShow, depth + 1, parentCommentId: n.comment.id),
                      if (hasMoreReplies) _buildShowMoreButton(n, depth + 1),
                    ],
                  ),
          ),
        );
      }
    }
    return out;
  }

  Widget _buildShowMoreButton(_CommentNode node, int replyDepth) {
    final remainingCount = node.children.length - 10;
    const maxDepth = 4;
    const indentPerLevel = 16.0;
    final cappedDepth = replyDepth > maxDepth ? maxDepth : replyDepth;
    final leftMargin = indentPerLevel * cappedDepth;
    final threadColor = _threadColors[(replyDepth - 1) % _threadColors.length];
    final localizations = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.only(left: leftMargin),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: threadColor.withValues(alpha: 0.4), width: 2),
        ),
      ),
      child: TextButton.icon(
        onPressed: () => _onShowMoreReplies(node.comment.id),
        icon: const Icon(Icons.subdirectory_arrow_right_rounded, size: 16),
        label: Text(
          localizations?.showMoreReplies(remainingCount) ?? "Show $remainingCount more ${remainingCount == 1 ? 'reply' : 'replies'}",
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          foregroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildCommentBlock(_CommentNode node, int depth, {String? parentCommentId, bool isLastChild = false}) {
    final c = node.comment;
    final localizations = AppLocalizations.of(context);
    final timeAgo = formatRelativeTime(context, c.createdAt);
    final hasReplies = node.children.isNotEmpty;
    final isCollapsed = _collapsedIds.contains(c.id);
    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    final totalReplyCount = _countAllReplies(node);
    final displayName = c.authorDisplayName ?? c.authorUsername;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Handle flagged comments (5+ reports) - hide by default with "Show anyway" option
    // Note: comments with 10+ reports are soft-deleted server-side and excluded from responses entirely
    final shouldShowFlagged = _showFlaggedComments.contains(c.id);
    if (c.isFlagged && !shouldShowFlagged) {
      Widget flaggedContent = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 20,
              color: colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.flaggedContent ?? "Flagged Content",
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizations?.flaggedContentMessage ??
                        "This content has been flagged by multiple users",
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _showFlaggedComments.add(c.id);
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                localizations?.showAnyway ?? "Show anyway",
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );

      if (depth >= 1) {
        const maxDepth = 4;
        const indentPerLevel = 16.0;
        final cappedDepth = depth > maxDepth ? maxDepth : depth;
        final leftMargin = indentPerLevel * cappedDepth;
        final threadColor = _threadColors[(depth - 1) % _threadColors.length];

        flaggedContent = Container(
          margin: EdgeInsets.only(left: leftMargin),
          padding: const EdgeInsets.only(left: 12, bottom: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: threadColor.withValues(alpha: 0.4), width: 2),
            ),
          ),
          child: flaggedContent,
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: flaggedContent,
      );
    }

    Widget commentContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildUserAvatar(context, c.authorAvatarUrl, c.authorUsername, radius: depth >= 1 ? 14 : 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name row: display name + relative time
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.viewerIsMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        localizations?.youLabel ?? "You",
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Comment body
              Text(
                c.content,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.87),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              // Action row
              Row(
                children: [
                  if (isLoggedIn)
                    _CommentActionButton(
                      icon: Icons.reply_rounded,
                      label: localizations?.replyAction ?? "Reply",
                      onTap: () => _onReply(c),
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  if (c.viewerIsMe) ...[
                    if (isLoggedIn) const SizedBox(width: 16),
                    _CommentActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: localizations?.delete ?? "Delete",
                      onTap: () => _onDeleteComment(c.id),
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                  ],
                  // Add report button for non-owner comments when logged in
                  if (isLoggedIn && !c.viewerIsMe) ...[
                    const SizedBox(width: 16),
                    _CommentActionButton(
                      icon: Icons.flag_outlined,
                      label: localizations?.report ?? "Report",
                      onTap: () => _onReportComment(c.id),
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                  if (hasReplies) ...[
                    if (isLoggedIn || c.viewerIsMe) const SizedBox(width: 16),
                    _CommentActionButton(
                      icon: isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                      label: isCollapsed
                          ? (localizations?.replyCount(totalReplyCount) ?? "$totalReplyCount ${totalReplyCount == 1 ? 'reply' : 'replies'}")
                          : (localizations?.hideReplies ?? "Hide"),
                      onTap: () => _onToggleCollapse(c.id),
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );

    // Nested comments with colored thread lines
    if (depth >= 1) {
      const maxDepth = 4;
      const indentPerLevel = 16.0;
      final cappedDepth = depth > maxDepth ? maxDepth : depth;
      final leftMargin = indentPerLevel * cappedDepth;
      final threadColor = _threadColors[(depth - 1) % _threadColors.length];

      if (isLastChild) {
        commentContent = Container(
          margin: EdgeInsets.only(left: leftMargin),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: threadColor.withValues(alpha: 0.4), width: 2),
            ),
          ),
          child: commentContent,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: commentContent,
        );
      } else {
        return Container(
          margin: EdgeInsets.only(left: leftMargin),
          padding: const EdgeInsets.only(left: 12, bottom: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: threadColor.withValues(alpha: 0.4), width: 2),
            ),
          ),
          child: commentContent,
        );
      }
    }

    // Root comments separated by a subtle divider
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: commentContent,
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmerBase = colorScheme.onSurface.withValues(alpha: 0.06);
    final shimmerHighlight = colorScheme.onSurface.withValues(alpha: 0.1);

    Widget shimmerBlock({double avatarRadius = 16, double nameWidth = 100, double contentWidth = 200}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: avatarRadius, backgroundColor: shimmerBase),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: nameWidth,
                        height: 12,
                        decoration: BoxDecoration(
                          color: shimmerHighlight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerBase,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: contentWidth,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: contentWidth * 0.6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 10,
                        decoration: BoxDecoration(
                          color: shimmerBase,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 50, height: 10,
                        decoration: BoxDecoration(
                          color: shimmerBase,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        shimmerBlock(nameWidth: 120, contentWidth: 240),
        shimmerBlock(nameWidth: 90, contentWidth: 200),
        shimmerBlock(nameWidth: 110, contentWidth: 180),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.noCommentsYet ?? "No comments yet",
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              localizations?.beFirstToComment ?? "Be the first to share your thoughts!",
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showInfo(context, localizations?.pleaseLogInToComment ?? "Please log in to comment");
      return;
    }
    if (widget.auth?.isSoftBanned == true || widget.auth?.isPermanentlyBanned == true) {
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showError(context, localizations?.cannotCommentWhileBanned ?? "You cannot comment while your account is suspended");
      return;
    }

    HapticFeedback.lightImpact();

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
    _initializeCollapsedState();

    // Restore scroll position after build if not already restored
    if (!_hasRestoredInitialScroll &&
        !widget.commentsController.isLoading &&
        widget.commentsController.comments.isNotEmpty) {
      final savedPosition = _uiState.scrollPosition;
      if (savedPosition > 0) {
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
    final sheetHeight = screenHeight * 0.75;

    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    final isBanned = widget.auth?.isSoftBanned == true || widget.auth?.isPermanentlyBanned == true;
    final userAvatar = widget.auth?.me?["avatar_url"]?.toString();
    final username = widget.auth?.me?["username"]?.toString() ?? "";
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final localizations = AppLocalizations.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: sheetHeight,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 48), // Balance the close button
                Expanded(
                  child: Text(
                    localizations?.comments ?? "Comments",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),
          // Comment count
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              localizations?.commentCount(widget.commentsController.comments.length) ?? "${widget.commentsController.comments.length} ${widget.commentsController.comments.length == 1 ? 'comment' : 'comments'}",
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          // Comments list
          Expanded(
            child: widget.commentsController.isLoading
                ? _buildShimmerLoading(context)
                : widget.commentsController.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: colorScheme.error.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              localizations?.couldntLoadComments ?? "Couldn't load comments",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => widget.commentsController.load(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(localizations?.retry ?? "Retry"),
                            ),
                          ],
                        ),
                      )
                    : widget.commentsController.comments.isEmpty
                        ? _buildEmptyState(context)
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            children: _buildCommentList(
                              _buildCommentTree(widget.commentsController.comments),
                              0,
                            ),
                          ),
          ),
          // Comment input
          if (isBanned) ...[
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.auth?.isPermanentlyBanned == true
                          ? (localizations?.accountPermanentlyBanned ?? "Account Permanently Suspended")
                          : widget.auth?.softBannedUntil != null
                              ? localizations?.accountSoftBannedUntil(
                                    formatDate(context, widget.auth!.softBannedUntil!),
                                  ) ??
                                  "Account Temporarily Suspended"
                              : (localizations?.cannotCommentWhileBanned ?? "You cannot comment while your account is suspended"),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLoggedIn) ...[
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply indicator
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: _replyingToId != null && _replyingToUsername != null
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.reply_rounded, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                        children: [
                                          TextSpan(text: localizations?.replyingTo ?? "Replying to "),
                                          TextSpan(
                                            text: "@$_replyingToUsername",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() {
                                      _replyingToId = null;
                                      _replyingToUsername = null;
                                    }),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Input row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: buildUserAvatar(
                            context,
                            userAvatar,
                            username,
                            radius: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _focusNode,
                            maxLines: 4,
                            minLines: 1,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            style: textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: _replyingToId != null
                                  ? (localizations?.writeAReply ?? "Write a reply...")
                                  : (localizations?.shareYourThoughts ?? "Share your thoughts..."),
                              hintStyle: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: colorScheme.primary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              counterText: "",
                              filled: true,
                              fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Animated send button
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) => ScaleTransition(
                              scale: animation,
                              child: FadeTransition(opacity: animation, child: child),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    key: const ValueKey("loading"),
                                    width: 40,
                                    height: 40,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : _hasText
                                    ? IconButton(
                                        key: const ValueKey("send"),
                                        onPressed: _submitComment,
                                        icon: Icon(
                                          Icons.send_rounded,
                                          color: colorScheme.primary,
                                          size: 22,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                          shape: const CircleBorder(),
                                          fixedSize: const Size(40, 40),
                                        ),
                                        tooltip: localizations?.postComment ?? "Post comment",
                                      )
                                    : const SizedBox(key: ValueKey("empty"), width: 40, height: 40),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                localizations?.logInToComment ?? "Log in to comment",
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
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

/// Compact action button used beneath each comment (Reply, Delete, expand/collapse).
class _CommentActionButton extends StatelessWidget {
  const _CommentActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
