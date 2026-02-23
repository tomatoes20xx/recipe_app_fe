import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../collections/add_to_collection_bottom_sheet.dart";
import "../collections/collection_api.dart";
import "../collections/collection_detail_controller.dart";
import "../collections/collection_models.dart";
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

  Future<void> _showCollectionSheet(String recipeId) async {
    final changed = await showAddToCollectionBottomSheet(
      context: context,
      apiClient: widget.apiClient,
      recipeId: recipeId,
    );
    if (changed && mounted) {
      _controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_collectionName),
        actions: [
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
                    Text(localizations?.renameCollection ?? "Rename"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "delete",
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    Text(
                      localizations?.deleteCollection ?? "Delete",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
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
            padding: const EdgeInsets.all(16),
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
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                              recipeId: recipe.id,
                              apiClient: widget.apiClient,
                              auth: widget.auth,
                              shoppingListController:
                                  widget.shoppingListController,
                            ),
                          ),
                        );
                        if (mounted) {
                          _controller.refresh();
                        }
                      },
                      onLongPress: () =>
                          _showCollectionSheet(recipe.id),
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
}
