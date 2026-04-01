import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../localization/app_localizations.dart';
import '../reports/report_bottom_sheet.dart';
import '../reports/report_models.dart';
import '../utils/error_utils.dart';
import '../widgets/common/app_bottom_sheet.dart';
import 'comment_input_section.dart';
import 'comment_list_view.dart';
import 'comment_models.dart';
import 'comment_tree.dart';
import 'comments_controller.dart';
import 'comments_ui_state.dart';
import 'recipe_api.dart';

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

  await showAppBottomSheet(
    context: context,
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
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  bool _hasText = false;
  String? _replyingToId;
  String? _replyingToUsername;

  CommentsUIState get _uiState => commentsUIStateCache.putIfAbsent(
    widget.recipeId,
    () => CommentsUIState(collapsedIds: {}, fullyExpandedIds: {}),
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
      final tree = buildCommentTree(widget.commentsController.comments);
      final newCollapsedIds = <String>{};
      void collectCommentIdsWithReplies(List<CommentNode> nodes) {
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
    commentsUIStateCache[widget.recipeId] = _uiState.copyWith(
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
      _updateUIState(collapsedIds: newCollapsedIds, fullyExpandedIds: newFullyExpandedIds);
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
      child: SafeArea(
        top: false,
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
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                localizations?.commentCount(widget.commentsController.comments.length) ??
                    "${widget.commentsController.comments.length} ${widget.commentsController.comments.length == 1 ? 'comment' : 'comments'}",
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // Comments list
            Expanded(
              child: CommentListView(
                commentsController: widget.commentsController,
                collapsedIds: _collapsedIds,
                fullyExpandedIds: _fullyExpandedIds,
                scrollController: _scrollController,
                auth: widget.auth,
                onReply: _onReply,
                onDeleteComment: _onDeleteComment,
                onReportComment: _onReportComment,
                onToggleCollapse: _onToggleCollapse,
                onShowMoreReplies: _onShowMoreReplies,
              ),
            ),
            // Comment input
            CommentInputSection(
              auth: widget.auth,
              commentController: _commentController,
              focusNode: _focusNode,
              replyingToId: _replyingToId,
              replyingToUsername: _replyingToUsername,
              isSubmitting: _isSubmitting,
              hasText: _hasText,
              onSubmit: _submitComment,
              onCancelReply: () => setState(() {
                _replyingToId = null;
                _replyingToUsername = null;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
