import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../collections/collection_api.dart";
import "../collections/collection_picker_bottom_sheet.dart";
import "../collections/collections_controller.dart";
import "../feed/saved_recipes_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../users/user_api.dart";
import "../utils/error_utils.dart";
import "../widgets/common/recipe_grid_card.dart";
import "../widgets/empty_state_widget.dart";
import "collection_detail_screen.dart";

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
  });

  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final SavedRecipesController _savedController;
  late final CollectionsController _collectionsController;
  late final CollectionApi _collectionApi;
  final ScrollController _savedScrollController = ScrollController();

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _savedController = SavedRecipesController(
      userApi: UserApi(widget.apiClient),
    );
    _collectionApi = CollectionApi(widget.apiClient);
    _collectionsController = CollectionsController(
      collectionApi: _collectionApi,
    );

    _savedController.addListener(_onChanged);
    _collectionsController.addListener(_onChanged);

    _savedScrollController.addListener(() {
      if (_savedScrollController.hasClients &&
          _savedScrollController.position.pixels >
              _savedScrollController.position.maxScrollExtent - 300) {
        _savedController.loadMore();
      }
    });

    _savedController.loadInitial();
    _collectionsController.loadCollections();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging && _isSelectionMode) {
      _exitSelectionMode();
    }
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
      final allIds = _savedController.items.map((e) => e.id).toSet();
      if (_selectedIds.containsAll(allIds)) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
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
        await _savedController.refresh();
        _collectionsController.loadCollections();
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
        await _savedController.refresh();
        _collectionsController.loadCollections();
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

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _savedScrollController.dispose();
    _savedController.removeListener(_onChanged);
    _savedController.dispose();
    _collectionsController.removeListener(_onChanged);
    _collectionsController.dispose();
    super.dispose();
  }

  Future<void> _showCreateCollectionDialog() async {
    final localizations = AppLocalizations.of(context);
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(localizations?.createCollection ?? "Create Collection"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: localizations?.enterCollectionName ??
                "Enter collection name",
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
            child: Text(localizations?.create ?? "Create"),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      try {
        await _collectionsController.createCollection(name);
        if (mounted) {
          ErrorUtils.showSuccess(
            context,
            localizations?.collectionCreated ?? "Collection created",
          );
        }
      } catch (e) {
        if (mounted) ErrorUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
              : Text(localizations?.savedRecipes ?? "Saved Recipes"),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: localizations?.selectAll ?? "Select All",
                    onPressed: _toggleSelectAll,
                  ),
                ]
              : null,
          bottom: _isSelectionMode
              ? null
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: localizations?.allSaved ?? "All"),
                    Tab(text: localizations?.collections ?? "Collections"),
                  ],
                ),
        ),
        body: _isSelectionMode
            ? Stack(
                children: [
                  _AllSavedTab(
                    controller: _savedController,
                    scrollController: _savedScrollController,
                    apiClient: widget.apiClient,
                    auth: widget.auth,
                    shoppingListController: widget.shoppingListController,
                    onCollectionChanged: () =>
                        _collectionsController.loadCollections(),
                    isSelectionMode: true,
                    selectedIds: _selectedIds,
                    onToggleSelection: _toggleSelection,
                    onEnterSelectionMode: _enterSelectionMode,
                  ),
                  // Bottom action bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SelectionActionBar(
                      selectedCount: _selectedIds.length,
                      isProcessing: _isBulkProcessing,
                      onMoveToCollection: _bulkMove,
                      onDelete: _bulkDelete,
                    ),
                  ),
                ],
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _AllSavedTab(
                    controller: _savedController,
                    scrollController: _savedScrollController,
                    apiClient: widget.apiClient,
                    auth: widget.auth,
                    shoppingListController: widget.shoppingListController,
                    onCollectionChanged: () =>
                        _collectionsController.loadCollections(),
                    isSelectionMode: false,
                    selectedIds: _selectedIds,
                    onToggleSelection: _toggleSelection,
                    onEnterSelectionMode: _enterSelectionMode,
                  ),
                  _CollectionsTab(
                    controller: _collectionsController,
                    collectionApi: _collectionApi,
                    apiClient: widget.apiClient,
                    auth: widget.auth,
                    shoppingListController: widget.shoppingListController,
                    onCreateCollection: _showCreateCollectionDialog,
                    onCollectionChanged: () => _savedController.refresh(),
                  ),
                ],
              ),
        floatingActionButton: _isSelectionMode
            ? null
            : AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  if (_tabController.index != 1) {
                    return const SizedBox.shrink();
                  }
                  return FloatingActionButton(
                    onPressed: _showCreateCollectionDialog,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: const Icon(Icons.add),
                  );
                },
              ),
      ),
    );
  }
}

// --- Selection Action Bar ---

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.isProcessing,
    required this.onMoveToCollection,
    required this.onDelete,
  });

  final int selectedCount;
  final bool isProcessing;
  final VoidCallback onMoveToCollection;
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
            : Row(
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

// --- All Saved Tab ---

class _AllSavedTab extends StatefulWidget {
  const _AllSavedTab({
    required this.controller,
    required this.scrollController,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
    required this.onCollectionChanged,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
  });

  final SavedRecipesController controller;
  final ScrollController scrollController;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;
  final VoidCallback onCollectionChanged;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onEnterSelectionMode;

  @override
  State<_AllSavedTab> createState() => _AllSavedTabState();
}

class _AllSavedTabState extends State<_AllSavedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;

    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.items.isEmpty) {
      return ErrorStateWidget(
        message: controller.error!,
        onRetry: () => controller.loadInitial(),
      );
    }

    if (controller.items.isEmpty) {
      final localizations = AppLocalizations.of(context);
      return EmptyStateWidget(
        icon: Icons.bookmark_border,
        title: localizations?.noSavedRecipes ?? "No saved recipes",
        description: localizations?.startBookmarkingRecipes ??
            "Start bookmarking recipes to save them here",
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: widget.isSelectionMode ? 80 : 16,
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
                  if (index >= controller.items.length) {
                    return Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Center(
                          child: CircularProgressIndicator()),
                    );
                  }

                  final recipe = controller.items[index];
                  return RepaintBoundary(
                    child: RecipeGridCard(
                      recipe: recipe,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: widget.selectedIds.contains(recipe.id),
                      onTap: () {
                        if (widget.isSelectionMode) {
                          widget.onToggleSelection(recipe.id);
                        } else {
                          _navigateToDetail(recipe.id);
                        }
                      },
                      onLongPress: () {
                        if (!widget.isSelectionMode) {
                          widget.onEnterSelectionMode(recipe.id);
                        }
                      },
                    ),
                  );
                },
                childCount: controller.items.length +
                    (controller.isLoadingMore ? 1 : 0),
              ),
            ),
          ),
          if (controller.isLoadingMore)
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
      widget.controller.refresh();
    }
  }
}

// --- Collections Tab ---

class _CollectionsTab extends StatefulWidget {
  const _CollectionsTab({
    required this.controller,
    required this.collectionApi,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
    required this.onCreateCollection,
    required this.onCollectionChanged,
  });

  final CollectionsController controller;
  final CollectionApi collectionApi;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;
  final VoidCallback onCreateCollection;
  final VoidCallback onCollectionChanged;

  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return ErrorStateWidget(
        message: controller.error!,
        onRetry: () => controller.loadCollections(),
      );
    }

    if (controller.items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.collections_bookmark_outlined,
        title: localizations?.noCollections ?? "No collections yet",
        description: localizations?.createFirstCollection ??
            "Create your first collection to organize your saved recipes",
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadCollections,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: controller.items.length,
        itemBuilder: (context, index) {
          final collection = controller.items[index];
          return ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.collections_bookmark_outlined,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            title: Text(
              collection.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              localizations?.nRecipes(collection.recipeCount) ??
                  "${collection.recipeCount} recipes",
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailScreen(
                    collection: collection,
                    apiClient: widget.apiClient,
                    auth: widget.auth,
                    shoppingListController:
                        widget.shoppingListController,
                  ),
                ),
              );
              // Refresh both collections and saved recipes lists
              if (mounted) {
                controller.loadCollections();
                widget.onCollectionChanged();
              }
            },
          );
        },
      ),
    );
  }
}
