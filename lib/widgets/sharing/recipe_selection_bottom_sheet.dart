import "package:flutter/material.dart";

import "../../localization/app_localizations.dart";
import "../../shopping/shopping_list_models.dart";
import "../../utils/ui_utils.dart";

/// Bottom sheet for selecting recipes from shopping list to share
Future<void> showRecipeSelectionBottomSheet({
  required BuildContext context,
  required List<ShoppingListItem> allItems,
  required Function(List<String> recipeIds) onRecipesSelected,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RecipeSelectionBottomSheet(
      allItems: allItems,
      onRecipesSelected: onRecipesSelected,
    ),
  );
}

class _RecipeSelectionBottomSheet extends StatefulWidget {
  const _RecipeSelectionBottomSheet({
    required this.allItems,
    required this.onRecipesSelected,
  });

  final List<ShoppingListItem> allItems;
  final Function(List<String> recipeIds) onRecipesSelected;

  @override
  State<_RecipeSelectionBottomSheet> createState() => _RecipeSelectionBottomSheetState();
}

class _RecipeSelectionBottomSheetState extends State<_RecipeSelectionBottomSheet> {
  final Set<String> _selectedRecipeIds = {};
  late List<_RecipeGroup> _recipeGroups;

  @override
  void initState() {
    super.initState();
    _recipeGroups = _groupItemsByRecipe();
  }

  List<_RecipeGroup> _groupItemsByRecipe() {
    final Map<String, List<ShoppingListItem>> grouped = {};

    for (final item in widget.allItems) {
      final key = item.recipeId ?? "__no_recipe__";
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Convert to RecipeGroup objects
    final groups = <_RecipeGroup>[];
    for (final entry in grouped.entries) {
      if (entry.key == "__no_recipe__") continue; // Skip non-recipe items

      final items = entry.value;
      final firstItem = items.first;

      groups.add(_RecipeGroup(
        recipeId: entry.key,
        recipeName: firstItem.recipeName ?? "Unknown Recipe",
        recipeImage: firstItem.recipeImage,
        itemCount: items.length,
        checkedCount: items.where((item) => item.isChecked).length,
      ));
    }

    return groups;
  }

  void _toggleRecipe(String recipeId) {
    setState(() {
      if (_selectedRecipeIds.contains(recipeId)) {
        _selectedRecipeIds.remove(recipeId);
      } else {
        _selectedRecipeIds.add(recipeId);
      }
    });
  }

  void _handleShare() {
    if (_selectedRecipeIds.isEmpty) return;

    Navigator.of(context).pop();
    widget.onRecipesSelected(_selectedRecipeIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  localizations?.selectRecipesToShare ?? "Select Recipes to Share",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  localizations?.selectRecipesDescription ?? "Choose which recipe ingredients to share with your followers",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Recipe list
              Expanded(
                child: _recipeGroups.isEmpty
                    ? Center(
                        child: Text(
                          localizations?.noRecipesInShoppingList ?? "No recipes in shopping list",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _recipeGroups.length,
                        itemBuilder: (context, index) {
                          final group = _recipeGroups[index];
                          final isSelected = _selectedRecipeIds.contains(group.recipeId);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggleRecipe(group.recipeId),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              secondary: group.recipeImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: RecipeImageWidget(
                                        imageUrl: group.recipeImage!,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const RecipeFallbackImage(
                                      width: 60,
                                      height: 60,
                                      iconSize: 30,
                                    ),
                              title: Text(
                                group.recipeName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "${group.itemCount} ${group.itemCount == 1 ? 'item' : 'items'} • ${group.checkedCount} checked",
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _selectedRecipeIds.isEmpty ? null : _handleShare,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _selectedRecipeIds.isEmpty
                          ? (localizations?.selectRecipes ?? "Select Recipes")
                          : (localizations?.shareSelectedRecipes ?? "Share ${_selectedRecipeIds.length} ${_selectedRecipeIds.length == 1 ? 'Recipe' : 'Recipes'}"),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecipeGroup {
  final String recipeId;
  final String recipeName;
  final String? recipeImage;
  final int itemCount;
  final int checkedCount;

  _RecipeGroup({
    required this.recipeId,
    required this.recipeName,
    this.recipeImage,
    required this.itemCount,
    required this.checkedCount,
  });
}
