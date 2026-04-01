import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../localization/app_localizations.dart';
import '../utils/ui_utils.dart';
import 'comment_models.dart';
import 'comment_tree.dart';
import 'comments_controller.dart';

class CommentActionButton extends StatelessWidget {
  const CommentActionButton({
    super.key,
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

class CommentListView extends StatefulWidget {
  const CommentListView({
    super.key,
    required this.commentsController,
    required this.collapsedIds,
    required this.fullyExpandedIds,
    required this.scrollController,
    required this.auth,
    required this.onReply,
    required this.onDeleteComment,
    required this.onReportComment,
    required this.onToggleCollapse,
    required this.onShowMoreReplies,
  });

  final CommentsController commentsController;
  final Set<String> collapsedIds;
  final Set<String> fullyExpandedIds;
  final ScrollController scrollController;
  final AuthController? auth;
  final void Function(Comment) onReply;
  final Future<void> Function(String) onDeleteComment;
  final Future<void> Function(String) onReportComment;
  final void Function(String) onToggleCollapse;
  final void Function(String) onShowMoreReplies;

  @override
  State<CommentListView> createState() => _CommentListViewState();
}

class _CommentListViewState extends State<CommentListView> {
  final Set<String> _showFlaggedComments = {};

  int _countAllReplies(CommentNode node) {
    int count = node.children.length;
    for (final child in node.children) {
      count += _countAllReplies(child);
    }
    return count;
  }

  List<Widget> _buildCommentList(List<CommentNode> nodes, int depth, {String? parentCommentId}) {
    final out = <Widget>[];
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final isLastChild = i == nodes.length - 1;
      out.add(_buildCommentBlock(n, depth, isLastChild: isLastChild, parentCommentId: parentCommentId));

      final hasReplies = n.children.isNotEmpty;
      final isCollapsed = widget.collapsedIds.contains(n.comment.id);

      if (hasReplies) {
        final isFullyExpanded = widget.fullyExpandedIds.contains(n.comment.id);
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

  Widget _buildShowMoreButton(CommentNode node, int replyDepth) {
    final remainingCount = node.children.length - 10;
    const maxDepth = 4;
    const indentPerLevel = 16.0;
    final cappedDepth = replyDepth > maxDepth ? maxDepth : replyDepth;
    final leftMargin = indentPerLevel * cappedDepth;
    final threadColor = threadColors[(replyDepth - 1) % threadColors.length];
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
        onPressed: () => widget.onShowMoreReplies(node.comment.id),
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

  Widget _buildCommentBlock(CommentNode node, int depth, {String? parentCommentId, bool isLastChild = false}) {
    final c = node.comment;
    final localizations = AppLocalizations.of(context);
    final timeAgo = formatRelativeTime(context, c.createdAt);
    final hasReplies = node.children.isNotEmpty;
    final isCollapsed = widget.collapsedIds.contains(c.id);
    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    final totalReplyCount = _countAllReplies(node);
    final displayName = c.authorDisplayName ?? c.authorUsername;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
        final threadColor = threadColors[(depth - 1) % threadColors.length];

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
              Text(
                c.content,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.87),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isLoggedIn)
                    CommentActionButton(
                      icon: Icons.reply_rounded,
                      label: localizations?.replyAction ?? "Reply",
                      onTap: () => widget.onReply(c),
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  if (c.viewerIsMe) ...[
                    if (isLoggedIn) const SizedBox(width: 16),
                    CommentActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: localizations?.delete ?? "Delete",
                      onTap: () => widget.onDeleteComment(c.id),
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                  ],
                  if (isLoggedIn && !c.viewerIsMe) ...[
                    const SizedBox(width: 16),
                    CommentActionButton(
                      icon: Icons.flag_outlined,
                      label: localizations?.report ?? "Report",
                      onTap: () => widget.onReportComment(c.id),
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                  if (hasReplies) ...[
                    if (isLoggedIn || c.viewerIsMe) const SizedBox(width: 16),
                    CommentActionButton(
                      icon: isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                      label: isCollapsed
                          ? (localizations?.replyCount(totalReplyCount) ?? "$totalReplyCount ${totalReplyCount == 1 ? 'reply' : 'replies'}")
                          : (localizations?.hideReplies ?? "Hide"),
                      onTap: () => widget.onToggleCollapse(c.id),
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

    if (depth >= 1) {
      const maxDepth = 4;
      const indentPerLevel = 16.0;
      final cappedDepth = depth > maxDepth ? maxDepth : depth;
      final leftMargin = indentPerLevel * cappedDepth;
      final threadColor = threadColors[(depth - 1) % threadColors.length];

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
                        width: 40,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerBase,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 50,
                        height: 10,
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.commentsController.isLoading) {
      return _buildShimmerLoading(context);
    }
    if (widget.commentsController.error != null) {
      return Center(
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
      );
    }
    if (widget.commentsController.comments.isEmpty) {
      return _buildEmptyState(context);
    }
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: _buildCommentList(
        buildCommentTree(widget.commentsController.comments),
        0,
      ),
    );
  }
}
