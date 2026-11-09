import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_models.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/app_tokens.dart";
import "../users/liked_recipes_controller.dart";
import "../users/user_api.dart";
import "../widgets/common/paginated_recipe_grid.dart";

/// Recipes you liked. Opened from the Profile tab's library.
class LikedRecipesScreen extends StatefulWidget {
  const LikedRecipesScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;

  @override
  State<LikedRecipesScreen> createState() => _LikedRecipesScreenState();
}

class _LikedRecipesScreenState extends State<LikedRecipesScreen> {
  late final LikedRecipesController _liked = LikedRecipesController(userApi: UserApi(widget.apiClient));

  @override
  void dispose() {
    _liked.dispose();
    super.dispose();
  }

  /// Not reloaded on return (as before); pull to refresh drops a recipe you
  /// unliked on the detail screen.
  void _openRecipe(FeedItem recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(
        recipeId: recipe.id,
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
        title: Text(l?.likedRecipes ?? "Liked recipes"),
      ),
      body: PaginatedRecipeGrid(
        controller: _liked,
        onOpen: _openRecipe,
        emptyIcon: Icons.favorite_border,
        emptyTitle: l?.noLikedRecipesYet ?? "No liked recipes yet",
        emptyDescription: l?.likedRecipesEmptyDescription ?? "Recipes you like will appear here",
      ),
    );
  }
}
