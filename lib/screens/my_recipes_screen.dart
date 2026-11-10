import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_models.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "shell_navigation.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/app_tokens.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../widgets/common/paginated_recipe_grid.dart";
import "../widgets/common/profile_stats_card.dart";

/// Your full recipe list and the likes your recipes received. Opened from the
/// Profile tab ("See all" and the recipes stat). Recipes you liked have their
/// own screen, [LikedRecipesScreen], in the tab's library.
class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
    required this.username,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final String username;

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  late final UserRecipesController _mine;

  /// Source of the summary numbers; null while loading.
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _mine = UserRecipesController(userApi: UserApi(widget.apiClient), username: widget.username);
    _loadSummary();
  }

  @override
  void dispose() {
    _mine.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final profile = await UserApi(widget.apiClient).getUserProfile(widget.username);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  /// Like the old own-profile grid, the list isn't reloaded on return; pull
  /// to refresh picks up a recipe deleted on the detail screen.
  void _openRecipe(FeedItem recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(
        recipeId: recipe.id,
        seed: RecipeSeed.fromFeedItem(recipe),
        apiClient: widget.apiClient,
        auth: widget.auth,
        shoppingListController: widget.shoppingListController,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(l?.recipes ?? "Recipes"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ProfileStatsCard(
              stats: [
                ProfileStat(value: _profile?.recipesCount, label: l?.recipes ?? "Recipes"),
                ProfileStat(value: _profile?.totalLikesCount, label: l?.totalLikes ?? "Total Likes"),
              ],
            ),
          ),
          Expanded(
            child: PaginatedRecipeGrid(
              controller: _mine,
              onRefresh: _loadSummary,
              onOpen: _openRecipe,
              emptyIcon: Icons.restaurant_menu_outlined,
              emptyActionLabel: l?.createRecipe ?? "Create Recipe",
              emptyActionIcon: Icons.add_rounded,
              onEmptyAction: () => ShellNavigation.go(context, ShellRequest.create),
              emptyTitle: l?.noRecipesYet ?? "No recipes yet",
              emptyDescription: l?.createYourFirstRecipe ?? "Create your first recipe!",
            ),
          ),
        ],
      ),
    );
  }
}
