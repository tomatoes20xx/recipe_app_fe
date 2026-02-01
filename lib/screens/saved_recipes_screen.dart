import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../config.dart";
import "../feed/feed_api.dart";
import "../feed/feed_models.dart";
import "../feed/saved_recipes_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../users/user_api.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";
import "../widgets/engagement_stat_widget.dart";

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({
    super.key,
    required this.apiClient,
    required this.auth,
  });

  final ApiClient apiClient;
  final AuthController auth;

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  late final SavedRecipesController controller;
  late final FeedApi feedApi;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = SavedRecipesController(
      userApi: UserApi(widget.apiClient),
    );
    feedApi = FeedApi(widget.apiClient);
    controller.addListener(_onChanged);
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >
              _scrollController.position.maxScrollExtent - 300) {
        controller.loadMore();
      }
    });
    controller.loadInitial();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  String buildImageUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    return "${Config.apiBaseUrl}$relativeUrl";
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.savedRecipes ?? "Saved Recipes");
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return EmptyStateWidget(
            icon: Icons.bookmark_border,
            title: localizations?.noSavedRecipes ?? "No saved recipes",
            description: localizations?.startBookmarkingRecipes ?? "Start bookmarking recipes to save them here",
          );
        },
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
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                final recipe = controller.items[index];
                return RepaintBoundary(
                  child: _RecipeGridCard(
                    recipe: recipe,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(
                            recipeId: recipe.id,
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                          ),
                        ),
                      );
                      // Refresh if recipe was unbookmarked from detail screen
                      if (mounted) {
                        controller.refresh();
                      }
                    },
                    buildImageUrl: buildImageUrl,
                  ),
                );
              },
              childCount: controller.items.length + (controller.isLoadingMore ? 1 : 0),
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
    );
  }
}

class _RecipeGridCard extends StatelessWidget {
  const _RecipeGridCard({
    required this.recipe,
    required this.onTap,
    required this.buildImageUrl,
  });

  final FeedItem recipe;
  final VoidCallback onTap;
  final String Function(String) buildImageUrl;

  @override
  Widget build(BuildContext context) {
    final firstImage = recipe.images.isNotEmpty ? recipe.images.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (firstImage != null)
            RecipeImageWidget(
              imageUrl: firstImage.url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 400,
              cacheHeight: 400,
            )
          else
            const RecipeFallbackImage(
              width: double.infinity,
              height: double.infinity,
              iconSize: 40,
            ),
          // Gradient overlay for better text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Overlay content
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Stats row
                Row(
                  children: [
                    EngagementStatWidget(
                      icon: Icons.favorite,
                      value: recipe.likes,
                      size: EngagementStatSize.small,
                      style: EngagementStatStyle.overlay,
                      showShadows: true,
                    ),
                    const SizedBox(width: 8),
                    EngagementStatWidget(
                      icon: Icons.comment_outlined,
                      value: recipe.comments,
                      size: EngagementStatSize.small,
                      style: EngagementStatStyle.overlay,
                      showShadows: true,
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
}
