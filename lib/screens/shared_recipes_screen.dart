import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_models.dart";
import "../recipes/recipe_detail_screen.dart";
import "../widgets/common/recipe_grid_card.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../recipes/recipe_api.dart";
import "../recipes/shared_recipes_controller.dart";
import "../shopping/shopping_list_controller.dart";
import "../widgets/empty_state_widget.dart";

class _DateGroup {
  final String label;
  final List<FeedItem> recipes;
  const _DateGroup(this.label, this.recipes);
}

class SharedRecipesScreen extends StatefulWidget {
  const SharedRecipesScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
  });

  final ApiClient apiClient;
  final AuthController? auth;
  final ShoppingListController shoppingListController;

  @override
  State<SharedRecipesScreen> createState() => _SharedRecipesScreenState();
}

class _SharedRecipesScreenState extends State<SharedRecipesScreen> {
  late final SharedRecipesController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = SharedRecipesController(
      recipeApi: RecipeApi(widget.apiClient),
    );
    controller.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    controller.loadInitial();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 300) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  List<_DateGroup> _buildGroups(AppLocalizations? localizations) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groupMap = <DateTime, List<FeedItem>>{};

    for (final item in controller.items) {
      final itemDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      groupMap[itemDate] ??= [];
      groupMap[itemDate]!.add(item);
    }

    return groupMap.entries.map((entry) {
      final date = entry.key;
      final String label;
      if (date == today) {
        label = localizations?.today ?? "Today";
      } else if (date == yesterday) {
        label = localizations?.yesterday ?? "Yesterday";
      } else {
        label = formatDate(context, date);
      }
      return _DateGroup(label, entry.value);
    }).toList();
  }

  Future<void> _showDeleteConfirmation(String shareId, String recipeTitle) async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeSharedRecipe ?? "Remove Shared Recipe"),
        content: Text(
          localizations?.removeSharedRecipeConfirm ??
              "Remove \"$recipeTitle\" from your shared recipes? This won't affect the original recipe.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.remove ?? "Remove"),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await controller.dismissRecipe(shareId);
        if (mounted) {
          ErrorUtils.showSuccess(context, localizations?.sharedRecipeRemoved ?? "Recipe removed from your shared list");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations?.error ?? "Error: ${e.toString()}"),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.sharedRecipes ?? "Shared Recipes"),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: Builder(
          builder: (context) {
            if (controller.isLoading && controller.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null && controller.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localizations?.error ?? "Error",
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        controller.error!,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => controller.refresh(),
                      child: Text(localizations?.retry ?? "Retry"),
                    ),
                  ],
                ),
              );
            }

            if (controller.items.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.folder_shared_outlined,
                title: localizations?.noSharedRecipes ?? "No recipes shared with you yet",
                description: localizations?.recipesSharedWithYou ??
                    "When someone shares a recipe with you, it will appear here",
              );
            }

            final groups = _buildGroups(localizations);

            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                for (final group in groups) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        group.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final recipe = group.recipes[index];
                          return RepaintBoundary(
                            child: GestureDetector(
                              onLongPress: () {
                                if (recipe.shareId != null) {
                                  _showDeleteConfirmation(recipe.shareId!, recipe.title);
                                }
                              },
                              child: RecipeGridCard(
                                recipe: recipe,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RecipeDetailScreen(
                                        recipeId: recipe.id,
                                        apiClient: widget.apiClient,
                                        auth: widget.auth,
                                        shoppingListController: widget.shoppingListController,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        childCount: group.recipes.length,
                      ),
                    ),
                  ),
                ],
                if (controller.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}
