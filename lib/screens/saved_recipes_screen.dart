import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../collections/collection_api.dart';
import '../collections/collection_picker_bottom_sheet.dart';
import '../collections/collections_controller.dart';
import '../feed/feed_models.dart';
import '../feed/saved_recipes_controller.dart';
import '../localization/app_localizations.dart';
import '../recipes/recipe_detail_screen.dart';
import '../shopping/shopping_list_controller.dart';
import '../users/user_api.dart';
import '../utils/error_utils.dart';
import '../utils/ui_utils.dart';
import '../widgets/empty_state_widget.dart';
import 'collection_detail_screen.dart';

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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);

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
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
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
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
          color: theme.colorScheme.surface,
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
      return const Center(child: CircularProgressIndicator());
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
                child: _SearchBar(
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
              sliver: _SkeletonGrid(),
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
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recipe = items[index];
                    return RepaintBoundary(
                      child: _SavedRecipeCard(
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
                        onCheckboxTap: () {
                          if (widget.isSelectionMode) {
                            widget.onToggleSelection(recipe.id);
                          } else {
                            widget.onEnterSelectionMode(recipe.id);
                          }
                        },
                      ),
                    );
                  },
                  childCount: items.length,
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
    if (mounted) widget.controller.refresh();
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Text(
            loc?.nSaved(count) ?? '$count saved',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SortChip(
                    label: loc?.recent ?? 'Recent',
                    active: sort == _SortMode.recent,
                    primaryColor: primary,
                    onTap: () => onChanged(_SortMode.recent),
                  ),
                  const SizedBox(width: 4),
                  _SortChip(
                    label: loc?.sortMostLiked ?? 'Most liked',
                    active: sort == _SortMode.mostLiked,
                    primaryColor: primary,
                    onTap: () => onChanged(_SortMode.mostLiked),
                  ),
                  const SizedBox(width: 4),
                  _SortChip(
                    label: loc?.sortAZ ?? 'A–Z',
                    active: sort == _SortMode.az,
                    primaryColor: primary,
                    onTap: () => onChanged(_SortMode.az),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: active ? primaryColor : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Saved Recipe Card ─────────────────────────────────────────────────────

class _SavedRecipeCard extends StatelessWidget {
  const _SavedRecipeCard({
    required this.recipe,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onCheckboxTap,
  });

  final FeedItem recipe;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCheckboxTap;

  String _formatCookTime(int? min, int? max) {
    if (min == null && max == null) return '';
    final t = min ?? max!;
    if (t >= 60) {
      final h = t ~/ 60;
      final m = t % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${t}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstImage = recipe.images.isNotEmpty ? recipe.images.first : null;
    final cookTime = _formatCookTime(recipe.cookingTimeMin, recipe.cookingTimeMax);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or fallback
            if (firstImage != null)
              RecipeImageWidget(
                imageUrl: firstImage.url,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 400,
              )
            else
              const RecipeFallbackImage(
                width: double.infinity,
                height: double.infinity,
                iconSize: 40,
              ),

            // Scrim gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),

            // Selection highlight overlay
            if (isSelected)
              Positioned.fill(
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),

            // Cook time badge — bottom left
            if (cookTime.isNotEmpty)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        cookTime,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Title — bottom, above badge
            Positioned(
              left: 10,
              right: 36,
              bottom: cookTime.isNotEmpty ? 30 : 10,
              child: Text(
                recipe.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Checkbox circle — top right (always visible)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onCheckboxTap,
                child: _SelectCircle(selected: isSelected),
              ),
            ),

            // Selected outline ring
            if (isSelected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? primary : Colors.white.withValues(alpha: 0.8),
        border: selected
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
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
              child: _SearchBar(
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
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumb
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.collections_bookmark_rounded,
                color: theme.colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)?.nRecipes(recipeCount) ??
                        '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton loader ───────────────────────────────────────────────────────

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  static const int _itemCount = 6;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _SkeletonCard(
          delay: Duration(milliseconds: index * 80),
        ),
        childCount: _itemCount,
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard({this.delay = Duration.zero});

  final Duration delay;

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: _anim,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(color: color),
      ),
    );
  }
}

