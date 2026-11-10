import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../collections/collection_api.dart';
import '../collections/collection_picker_bottom_sheet.dart';
import '../collections/collections_controller.dart';
import '../feed/saved_recipes_controller.dart';
import '../feed/feed_models.dart';
import '../localization/app_localizations.dart';
import '../recipes/recipe_detail_screen.dart';
import '../shopping/shopping_list_controller.dart';
import '../users/user_api.dart';
import '../utils/error_utils.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/recipe_grid_tile.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/common/token_widgets.dart';
import '../widgets/empty_state_widget.dart';
import 'collection_detail_screen.dart';
import 'shell_navigation.dart';

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
        if (_selectedIds.isEmpty) _isSelectionMode = false;
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
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(allIds);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _bulkDelete() async {
    final localizations = AppLocalizations.of(context);
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeBookmarks ?? 'Remove Bookmarks'),
        content: Text(
          localizations?.removeSelectedBookmarksConfirm(count) ??
              'Remove $count recipes from saved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.delete ?? 'Delete'),
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
                'Removed $deleted recipes',
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
            localizations?.bulkMoveSuccess(moved) ?? 'Moved $moved recipes',
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
            Text(localizations?.createCollection ?? 'Create Collection'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: localizations?.enterCollectionName ??
                'Enter collection name',
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
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
            },
            child: Text(localizations?.create ?? 'Create'),
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
            localizations?.collectionCreated ?? 'Collection created',
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

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) _exitSelectionMode();
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
              ? Text(
                  localizations?.nSelected(_selectedIds.length) ??
                      '${_selectedIds.length} selected',
                )
              : Text(localizations?.savedRecipes ?? 'Saved Recipes'),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: localizations?.selectAll ?? 'Select All',
                    onPressed: _toggleSelectAll,
                  ),
                ]
              : null,
          bottom: _isSelectionMode
              ? null
              : TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: localizations?.allSaved ?? 'All'),
                    Tab(text: localizations?.collections ?? 'Collections'),
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
                  if (_tabController.index != 1) return const SizedBox.shrink();
                  return FloatingActionButton(
                    onPressed: _showCreateCollectionDialog,
                    child: const Icon(Icons.add),
                  );
                },
              ),
      ),
    );
  }
}

// ─── Selection Action Bar ───────────────────────────────────────────────────

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
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                      label: Text(
                        localizations?.moveToCollection ?? 'Move',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: selectedCount > 0 ? onDelete : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
                      label: Text(
                        localizations?.removeBookmarks ?? 'Remove',
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

// ─── All Saved Tab ─────────────────────────────────────────────────────────

enum _SortMode { recent, mostLiked, az }

extension _SortModeApi on _SortMode {
  String get apiValue => switch (this) {
        _SortMode.recent => 'newest',
        _SortMode.mostLiked => 'most_liked',
        _SortMode.az => 'title_asc',
      };
}

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SortMode _sort = _SortMode.recent;
  Timer? _debounce;
  bool _hasLoadedOnce = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Update local state without setState — no rebuild until API responds.
    _searchQuery = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      widget.controller.setParams(query: query, newSort: _sort.apiValue);
    });
  }

  void _onSortChanged(_SortMode sort) {
    setState(() => _sort = sort);
    _debounce?.cancel();
    widget.controller.setParams(query: _searchQuery, newSort: sort.apiValue);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;

    if (!controller.isLoading && controller.items.isNotEmpty) _hasLoadedOnce = true;

    // Full-screen spinner only on the very first load, before any data arrives.
    if (!_hasLoadedOnce && controller.isLoading && controller.items.isEmpty) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: RecipeGridSkeleton(),
      );
    }

    if (controller.error != null && controller.items.isEmpty) {
      return ErrorStateWidget(
        message: controller.error!,
        onRetry: () => controller.loadInitial(),
      );
    }

    final items = controller.items;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Search bar
          if (!widget.isSelectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TokenSearchField(
                  controller: _searchController,
                  hintText: AppLocalizations.of(context)?.searchSavedRecipes ??
                      'Search saved recipes',
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

          // Sort chips (hide while skeleton is showing)
          if (!widget.isSelectionMode && items.isNotEmpty && !controller.isLoading)
            SliverToBoxAdapter(
              child: _SortBar(
                sort: _sort,
                count: items.length,
                onChanged: _onSortChanged,
              ),
            ),

          // Skeleton grid while a search/sort reload is in flight
          if (controller.isLoading && _hasLoadedOnce)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(child: RecipeGridSkeleton()),
            )

          // Empty state
          else if (items.isEmpty && !controller.isLoading)
            SliverFillRemaining(
              child: _searchQuery.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.bookmark_border,
                      title: AppLocalizations.of(context)?.noSavedRecipes ??
                          'No saved recipes',
                      description:
                          AppLocalizations.of(context)?.startBookmarkingRecipes ??
                              'Start bookmarking recipes to save them here',
                      actionLabel: AppLocalizations.of(context)?.exploreRecipes ?? 'Explore recipes',
                      actionIcon: Icons.explore_outlined,
                      onAction: () => ShellNavigation.go(context, ShellRequest.home),
                    )
                  : EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: AppLocalizations.of(context)?.noMatches ??
                          'No matches',
                      description:
                          AppLocalizations.of(context)?.nothingMatches(_searchQuery) ??
                              'Nothing matches "$_searchQuery"',
                    ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                widget.isSelectionMode ? 80 : 16,
              ),
              sliver: SliverRecipeTileGrid(
                items: items,
                tileBuilder: (context, recipe) => RecipeGridTile(
                  recipe: recipe,
                  selected: widget.selectedIds.contains(recipe.id),
                  onTap: () {
                    if (widget.isSelectionMode) {
                      widget.onToggleSelection(recipe.id);
                    } else {
                      _navigateToDetail(recipe);
                    }
                  },
                  onSelectTap: () {
                    if (widget.isSelectionMode) {
                      widget.onToggleSelection(recipe.id);
                    } else {
                      widget.onEnterSelectionMode(recipe.id);
                    }
                  },
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

  Future<void> _navigateToDetail(FeedItem recipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipe.id,
          seed: RecipeSeed.fromFeedItem(recipe),
          apiClient: widget.apiClient,
          auth: widget.auth,
          shoppingListController: widget.shoppingListController,
        ),
      ),
    );
    if (mounted) widget.controller.refresh();
  }
}

// ─── Sort Bar ──────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.count,
    required this.onChanged,
  });

  final _SortMode sort;
  final int count;
  final ValueChanged<_SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final loc = AppLocalizations.of(context);

    // The count, then the sort chips; the row scrolls when the chips don't
    // fit (Georgian labels are long).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Text(
            loc?.nSaved(count) ?? '$count saved',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink2),
          ),
          const SizedBox(width: 12),
          Row(
                children: [
                  TokenChip(
                    label: loc?.recent ?? 'Recent',
                    selected: sort == _SortMode.recent,
                    onTap: () => onChanged(_SortMode.recent),
                  ),
                  const SizedBox(width: 8),
                  TokenChip(
                    label: loc?.sortMostLiked ?? 'Most liked',
                    selected: sort == _SortMode.mostLiked,
                    onTap: () => onChanged(_SortMode.mostLiked),
                  ),
                  const SizedBox(width: 8),
                  TokenChip(
                    label: loc?.sortAZ ?? 'A–Z',
                    selected: sort == _SortMode.az,
                    onTap: () => onChanged(_SortMode.az),
                  ),
                ],
          ),
        ],
      ),
    );
  }
}

// ─── Collections Tab ───────────────────────────────────────────────────────

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

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _hasLoadedOnce = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      widget.controller.setParams(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final localizations = AppLocalizations.of(context);

    if (controller.error != null && controller.items.isEmpty) {
      return ErrorStateWidget(
        message: controller.error!,
        onRetry: () => controller.loadCollections(),
      );
    }

    if (!controller.isLoading && controller.items.isNotEmpty) _hasLoadedOnce = true;

    final isEmpty = !controller.isLoading && controller.items.isEmpty;

    return RefreshIndicator(
      onRefresh: controller.loadCollections,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TokenSearchField(
                controller: _searchController,
                hintText: localizations?.searchCollections ?? 'Search collections',
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          // Subtle bar during search reloads; full spinner only on very first load.
          if (controller.isLoading && _hasLoadedOnce)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (controller.isLoading && !_hasLoadedOnce)
            const SliverToBoxAdapter(
              child: ListRowSkeleton(count: 4, leadingSize: 44),
            ),
          if (!controller.isLoading && isEmpty)
            SliverFillRemaining(
              child: EmptyStateWidget(
                icon: _searchController.text.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.collections_bookmark_outlined,
                title: _searchController.text.isNotEmpty
                    ? (localizations?.noMatches ?? 'No matches')
                    : (localizations?.noCollections ?? 'No collections yet'),
                description: _searchController.text.isNotEmpty
                    ? (localizations?.nothingMatches(_searchController.text) ??
                        'Nothing matches "${_searchController.text}"')
                    : (localizations?.createFirstCollection ??
                        'Create your first collection to organize your saved recipes'),
                actionLabel: _searchController.text.isNotEmpty
                    ? null
                    : (localizations?.createCollection ?? 'Create collection'),
                actionIcon: Icons.add_rounded,
                onAction: _searchController.text.isNotEmpty ? null : widget.onCreateCollection,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: controller.items.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final collection = controller.items[index];
                  return _CollectionCard(
                    name: collection.name,
                    recipeCount: collection.recipeCount,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CollectionDetailScreen(
                            collection: collection,
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                            shoppingListController: widget.shoppingListController,
                          ),
                        ),
                      );
                      if (mounted) {
                        controller.loadCollections();
                        widget.onCollectionChanged();
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.name,
    required this.recipeCount,
    required this.onTap,
  });

  final String name;
  final int recipeCount;
  final VoidCallback onTap;

  /// Styled like the Profile tab's library tiles: `card`, 1px `line`,
  /// radius 18, and a `soft` icon tile.
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.collections_bookmark_outlined, color: t.brandInk, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)?.nRecipes(recipeCount) ??
                          '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                      style: TextStyle(fontSize: 13, color: t.ink2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
