import "package:flutter/material.dart";
import "package:uuid/uuid.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../localization/app_localizations.dart";
import "../screens/shopping_list_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../shopping/shopping_list_models.dart";
import "../theme/app_tokens.dart";
import "../utils/error_utils.dart";
import "../widgets/common/app_bottom_sheet.dart";
import "recipe_detail_models.dart";
import "recipe_detail_parts.dart";

/// "Add to shopping list" from the recipe page: a sheet listing the
/// ingredients, with everything not ticked off (= not "I have it") selected,
/// amounts scaled to the chosen servings. Adds the selected ones, scaled.
Future<void> showAddToShoppingListSheet({
  required BuildContext context,
  required RecipeDetail recipe,
  required double scaleFactor,
  required Set<String> tickedIds,
  required ShoppingListController shoppingListController,
  required ApiClient apiClient,
  required AuthController? auth,
}) async {
  if (auth == null || !await requireAccount(context, auth, AccountReason.shoppingList)) return;
  if (!context.mounted) return;

  final added = await showAppBottomSheet<int>(
    context: context,
    builder: (_) => _AddToShoppingListSheet(
      recipe: recipe,
      scaleFactor: scaleFactor,
      tickedIds: tickedIds,
      shoppingListController: shoppingListController,
    ),
  );
  if (added == null || added == 0 || !context.mounted) return;

  final localizations = AppLocalizations.of(context);
  final navigator = Navigator.of(context);
  ErrorUtils.showSnackBar(
    context,
    (localizations?.nItemsAddedToList ?? "{n} items added to shopping list").replaceAll("{n}", "$added"),
    icon: Icons.check_circle,
    backgroundColor: AppTokens.of(context).primary,
    duration: const Duration(seconds: 4),
    actionLabel: localizations?.view ?? "View",
    onActionPressed: () => navigator.push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(
          controller: shoppingListController,
          apiClient: apiClient,
          auth: auth,
        ),
      ),
    ),
  );
}

class _AddToShoppingListSheet extends StatefulWidget {
  const _AddToShoppingListSheet({
    required this.recipe,
    required this.scaleFactor,
    required this.tickedIds,
    required this.shoppingListController,
  });

  final RecipeDetail recipe;
  final double scaleFactor;
  final Set<String> tickedIds;
  final ShoppingListController shoppingListController;

  @override
  State<_AddToShoppingListSheet> createState() => _AddToShoppingListSheetState();
}

class _AddToShoppingListSheetState extends State<_AddToShoppingListSheet> {
  late final Set<String> _selected = {
    for (final ing in widget.recipe.ingredients)
      if (!widget.tickedIds.contains(ing.id)) ing.id,
  };
  bool _isAdding = false;

  Future<void> _add() async {
    setState(() => _isAdding = true);
    const uuid = Uuid();
    final r = widget.recipe;
    final now = DateTime.now();
    final items = [
      for (final ing in r.ingredients)
        if (_selected.contains(ing.id))
          ShoppingListItem(
            id: uuid.v4(),
            ingredientId: ing.id,
            name: ing.displayName,
            quantity: ing.quantity == null ? null : ing.quantity! * widget.scaleFactor,
            unit: ing.unit,
            recipeId: r.id,
            recipeName: r.title,
            recipeImage: r.images.isNotEmpty ? r.images.first.url : null,
            addedAt: now,
          ),
    ];
    await widget.shoppingListController.addItems(items);
    if (mounted) Navigator.of(context).pop(items.length);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final ingredients = widget.recipe.ingredients;
    final count = _selected.length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      decoration: BoxDecoration(color: t.sheet, borderRadius: sheetTopRadius),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.only(top: 8), child: SheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l?.addIngredientsToShoppingList ?? "Add to shopping list",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (count == ingredients.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll(ingredients.map((i) => i.id));
                      }
                    }),
                    child: Text(count == ingredients.length
                        ? (l?.deselectAll ?? "Deselect all")
                        : (l?.selectAll ?? "Select all")),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  for (var i = 0; i < ingredients.length; i++)
                    _SheetRow(
                      line: RecipeIngredientLine.fromIngredient(ingredients[i], widget.scaleFactor),
                      selected: _selected.contains(ingredients[i].id),
                      showDivider: i < ingredients.length - 1,
                      onTap: () => setState(() {
                        final id = ingredients[i].id;
                        if (!_selected.remove(id)) _selected.add(id);
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: count == 0 || _isAdding ? null : _add,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _isAdding
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text((l?.addNItems ?? "Add {n} items").replaceAll("{n}", "$count")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.line, required this.selected, required this.showDivider, required this.onTap});

  final RecipeIngredientLine line;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: t.line)) : null,
        ),
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onTap()),
            const SizedBox(width: 4),
            Expanded(child: Text(line.name, style: TextStyle(fontSize: 15, color: t.ink))),
            if (line.amount.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                line.amount,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.brandInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
