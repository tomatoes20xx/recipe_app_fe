import "package:flutter/material.dart";
import "package:uuid/uuid.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_models.dart";
import "../screens/shopping_list_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../shopping/shopping_list_models.dart";
import "../utils/error_utils.dart";

class IngredientActionBar extends StatelessWidget {
  const IngredientActionBar({
    super.key,
    required this.selectedIngredients,
    required this.recipeId,
    required this.recipeName,
    this.recipeImage,
    required this.shoppingListController,
    required this.apiClient,
    required this.auth,
    required this.onMarkAsHave,
    required this.onCancel,
  });

  final List<RecipeIngredient> selectedIngredients;
  final String recipeId;
  final String recipeName;
  final String? recipeImage;
  final ShoppingListController shoppingListController;
  final ApiClient apiClient;
  final AuthController? auth;
  final VoidCallback onMarkAsHave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = selectedIngredients.length;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (localizations?.nItemsSelected ?? "{n} items selected")
                          .replaceAll("{n}", "$count"),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  // Already Have button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMarkAsHave,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(localizations?.alreadyHave ?? "Already Have"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add to Shopping List button
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _addToShoppingList(context),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(localizations?.addToShoppingList ?? "Add to List"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToShoppingList(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    const uuid = Uuid();

    // Convert selected ingredients to shopping list items
    final items = selectedIngredients.map((ingredient) {
      return ShoppingListItem(
        id: uuid.v4(),
        ingredientId: ingredient.id,
        name: ingredient.displayName,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        recipeId: recipeId,
        recipeName: recipeName,
        recipeImage: recipeImage,
        addedAt: DateTime.now(),
      );
    }).toList();

    // Add to shopping list
    await shoppingListController.addItems(items);

    // Show success snackbar
    if (context.mounted) {
      final count = items.length;
      // Capture the navigator and scaffoldMessenger before calling onCancel
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      ErrorUtils.showSnackBar(
        context,
        (localizations?.nItemsAddedToList ?? "{n} items added to shopping list")
            .replaceAll("{n}", "$count"),
        icon: Icons.check_circle,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        actionLabel: localizations?.view ?? "View",
        onActionPressed: () {
          scaffoldMessenger.hideCurrentSnackBar();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ShoppingListScreen(
                controller: shoppingListController,
                apiClient: apiClient,
                auth: auth,
              ),
            ),
          );
        },
      );

      // Call onCancel to dismiss the action bar
      onCancel();
    }
  }
}
