import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../recipes/recipe_detail_screen.dart";
import "../widgets/common/recipe_grid_card.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_api.dart";
import "../recipes/shared_recipes_controller.dart";
import "../shopping/shopping_list_controller.dart";
import "../widgets/empty_state_widget.dart";

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

            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= controller.items.length) {
                          if (controller.isLoadingMore) {
                            return Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          }
                          return null;
                        }

                        final recipe = controller.items[index];
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
                                    shoppingListController: widget.shoppingListController,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: controller.items.length + (controller.isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
