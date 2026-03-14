import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../collections/collection_api.dart";
import "../collections/collection_detail_controller.dart";
import "../collections/collection_models.dart";
import "../collections/collection_picker_bottom_sheet.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../utils/error_utils.dart";
import "../widgets/common/recipe_grid_card.dart";
import "../widgets/empty_state_widget.dart";

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collection,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
  });

  final Collection collection;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;

  @override
  State<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late final CollectionApi _collectionApi;
  late final CollectionDetailController _controller;
  late String _collectionName;
  final ScrollController _scrollController = ScrollController();

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    _collectionName = widget.collection.name;
    _collectionApi = CollectionApi(widget.apiClient);
    _controller = CollectionDetailController(
      collectionApi: _collectionApi,
      collectionId: widget.collection.id,
    );
    _controller.addListener(_onChanged);
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >
              _scrollController.position.maxScrollExtent - 300) {
        _controller.loadMore();
      }
    });
    _controller.loadInitial();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelectionMode(String recipeId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(recipeId);
    });
  }

  void _toggleSelection(String recipeId) {
    setState(() {
      if (_selectedIds.contains(recipeId)) {
        _selectedIds.remove(recipeId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(recipeId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final allIds = _controller.items.map((e) => e.id).toSet();
      if (_selectedIds.containsAll(allIds)) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  Future<void> _bulkMoveToBookmarks() async {
    final localizations = AppLocalizations.of(context);

    setState(() => _isBulkProcessing = true);
    try {
      await _collectionApi.bulkMove(
          _selectedIds.toList(), null);
      if (mounted) {
        _exitSelectionMode();
        setState(() => _isBulkProcessing = false);
        await _controller.refresh();
        if (mounted) {
          ErrorUtils.showSuccess(
            context,
            localizations?.movedToBookmarks ?? "Moved to bookmarks",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkProcessing = false);
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _bulkDelete() async {
    final localizations = AppLocalizations.of(context);
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeBookmarks ?? "Remove Bookmarks"),
        content: Text(
          localizations?.removeSelectedBookmarksConfirm(count) ??
              "Remove $count recipes from saved?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.delete ?? "Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBulkProcessing = true);
    try {
      final deleted = await _collectionApi.bulkDelete(_selectedIds.toList());
      if (mounted) {
        _exitSelectionMode();
        setState(() => _isBulkProcessing = false);
        await _controller.refresh();
        if (mounted) {
          ErrorUtils.showSuccess(
            context,
            localizations?.bulkRemoveSuccess(deleted) ??
                "Removed $deleted recipes",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkProcessing = false);
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _bulkMove() async {
    final localizations = AppLocalizations.of(context);

    final collection = await showCollectionPickerBottomSheet(
      context: context,
      apiClient: widget.apiClient,
    );
    if (collection == null || !mounted) return;

    setState(() => _isBulkProcessing = true);
    try {
      final moved = await _collectionApi.bulkMove(
          _selectedIds.toList(), collection.id);
      if (mounted) {
        _exitSelectionMode();
        setState(() => _isBulkProcessing = false);
        await _controller.refresh();
        if (mounted) {
          ErrorUtils.showSuccess(
            context,
            localizations?.bulkMoveSuccess(moved) ?? "Moved $moved recipes",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkProcessing = false);
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _showRenameDialog() async {
    final localizations = AppLocalizations.of(context);
    final nameController = TextEditingController(text: _collectionName);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(localizations?.renameCollection ?? "Rename Collection"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: localizations?.collectionName ?? "Collection name",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: Text(localizations?.save ?? "Save"),
          ),
        ],
      ),
    );

    if (name != null &&
        name.isNotEmpty &&
        name != _collectionName &&
        mounted) {
      try {
        await _collectionApi.renameCollection(widget.collection.id, name);
        if (mounted) {
          setState(() => _collectionName = name);
          ErrorUtils.showSuccess(
            context,
            localizations?.collectionRenamed ?? "Collection renamed",
          );
        }
      } catch (e) {
        if (mounted) ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final localizations = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(localizations?.deleteCollection ?? "Delete Collection"),
        content: Text(
          localizations?.deleteCollectionConfirm ??
              "Are you sure you want to delete this collection? Recipes will become regular bookmarks.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.delete ?? "Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _collectionApi.deleteCollection(widget.collection.id);
        if (mounted) {
          ErrorUtils.showSuccess(
            context,
            localizations?.collectionDeleted ?? "Collection deleted",
          );
          Navigator.of(context).pop(true); // signal parent to refresh
        }
      } catch (e) {
        if (mounted) ErrorUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                )
              : null,
          title: _isSelectionMode
              ? Text(localizations?.nSelected(_selectedIds.length) ??
                  "${_selectedIds.length} selected")
              : Text(_collectionName),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: localizations?.selectAll ?? "Select All",
                    onPressed: _toggleSelectAll,
                  ),
                ]
              : [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "rename") {
                        _showRenameDialog();
                      } else if (value == "delete") {
                        _showDeleteConfirmation();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "rename",
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(localizations?.renameCollection ??
                                "Rename"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 20,
                                color:
                                    Theme.of(context).colorScheme.error),
                            const SizedBox(width: 12),
                            Text(
                              localizations?.deleteCollection ?? "Delete",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
        ),
        body: _isSelectionMode
            ? Stack(
                children: [
                  _buildBody(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SelectionActionBar(
                      selectedCount: _selectedIds.length,
                      isProcessing: _isBulkProcessing,
                      onMoveToCollection: _bulkMove,
                      onMoveToBookmarks: _bulkMoveToBookmarks,
                      onDelete: _bulkDelete,
                    ),
                  ),
                ],
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null && _controller.items.isEmpty) {
      return ErrorStateWidget(
        message: _controller.error!,
        onRetry: () => _controller.loadInitial(),
      );
    }

    if (_controller.items.isEmpty) {
      final localizations = AppLocalizations.of(context);
      return EmptyStateWidget(
        icon: Icons.collections_bookmark_outlined,
        title: localizations?.emptyCollection ??
            "No recipes in this collection",
        description: localizations?.addRecipesToCollection ??
            "Add recipes to this collection by bookmarking them",
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: _isSelectionMode ? 80 : 16,
            ),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _controller.items.length) {
                    return Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Center(
                          child: CircularProgressIndicator()),
                    );
                  }

                  final recipe = _controller.items[index];
                  return RepaintBoundary(
                    child: RecipeGridCard(
                      recipe: recipe,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedIds.contains(recipe.id),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(recipe.id);
                        } else {
                          _navigateToDetail(recipe.id);
                        }
                      },
                      onLongPress: () {
                        if (_isSelectionMode) {
                          _toggleSelection(recipe.id);
                        } else {
                          _enterSelectionMode(recipe.id);
                        }
                      },
                    ),
                  );
                },
                childCount: _controller.items.length +
                    (_controller.isLoadingMore ? 1 : 0),
              ),
            ),
          ),
          if (_controller.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetail(String recipeId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipeId,
          apiClient: widget.apiClient,
          auth: widget.auth,
          shoppingListController: widget.shoppingListController,
        ),
      ),
    );
    if (mounted) {
      _controller.refresh();
    }
  }
}

// --- Selection Action Bar ---

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.isProcessing,
    required this.onMoveToCollection,
    required this.onMoveToBookmarks,
    required this.onDelete,
  });

  final int selectedCount;
  final bool isProcessing;
  final VoidCallback onMoveToCollection;
  final VoidCallback onMoveToBookmarks;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isProcessing
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectedCount > 0 ? onMoveToCollection : null,
                          icon: const Icon(Icons.drive_file_move_outlined,
                              size: 20),
                          label: Text(
                            localizations?.moveToCollection ??
                                "Move to Collection",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectedCount > 0 ? onMoveToBookmarks : null,
                          icon: const Icon(Icons.bookmark_outline, size: 20),
                          label: Text(
                            localizations?.movedToBookmarks ??
                                "Move to Bookmarks",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedCount > 0 ? onDelete : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.bookmark_remove_outlined,
                          size: 20),
                      label: Text(
                        localizations?.removeBookmarks ?? "Remove",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
