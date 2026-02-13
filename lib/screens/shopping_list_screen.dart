import "package:flutter/material.dart";

import "../localization/app_localizations.dart";
import "../shopping/shopping_list_controller.dart";
import "../shopping/shopping_list_models.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({
    super.key,
    required this.controller,
  });

  final ShoppingListController controller;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations?.shoppingList ?? "Shopping List"),
            if (widget.controller.isSyncing)
              Text(
                "Syncing...",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.controller.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (!widget.controller.isSyncing && widget.controller.checkedCount > 0)
            TextButton.icon(
              onPressed: () => _showClearCheckedDialog(),
              icon: const Icon(Icons.cleaning_services_outlined, size: 20),
              label: Text(localizations?.clearChecked ?? "Clear"),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          if (!widget.controller.isSyncing && widget.controller.totalCount > 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == "clear_all") {
                  _showClearAllDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "clear_all",
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        localizations?.clearAll ?? "Clear All",
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.controller.syncWithServer();
        },
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            if (widget.controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (widget.controller.isEmpty) {
              // Wrap EmptyStateWidget in scrollable to enable pull-to-refresh
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: EmptyStateWidget(
                    icon: Icons.shopping_cart_outlined,
                    title: localizations?.emptyShoppingList ?? "Shopping list is empty",
                    description: localizations?.emptyShoppingListMessage ?? "Add ingredients from recipes to create your shopping list",
                  ),
                ),
              );
            }

            return _buildShoppingList();
          },
        ),
      ),
    );
  }

  Widget _buildShoppingList() {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groups = widget.controller.groupedItems;

    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  icon: Icons.shopping_basket_outlined,
                  label: localizations?.total ?? "Total",
                  value: "${widget.controller.totalCount}",
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                ),
                _buildStat(
                  icon: Icons.check_circle_outline,
                  label: localizations?.checked ?? "Checked",
                  value: "${widget.controller.checkedCount}",
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                ),
                _buildStat(
                  icon: Icons.pending_outlined,
                  label: localizations?.remaining ?? "Remaining",
                  value: "${widget.controller.uncheckedCount}",
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),

        // Grouped items
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final group = groups[index];
                return _RecipeGroupCard(
                  group: group,
                  controller: widget.controller,
                  onRemoveRecipe: () => _showRemoveRecipeDialog(group),
                );
              },
              childCount: groups.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Future<void> _showClearCheckedDialog() async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.clearCheckedItems ?? "Clear checked items?"),
        content: Text(
          localizations?.clearCheckedItemsMessage ??
              "This will remove all checked items from your shopping list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.clear ?? "Clear"),
          ),
        ],
      ),
    );

    if (result == true) {
      await widget.controller.clearCheckedItems();
    }
  }

  Future<void> _showClearAllDialog() async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.clearAllItems ?? "Clear all items?"),
        content: Text(
          localizations?.clearAllItemsMessage ??
              "This will remove all items from your shopping list. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations?.clearAll ?? "Clear All"),
          ),
        ],
      ),
    );

    if (result == true) {
      await widget.controller.clearAll();
    }
  }

  Future<void> _showRemoveRecipeDialog(GroupedShoppingItems group) async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeRecipeItems ?? "Remove recipe items?"),
        content: Text(
          (localizations?.removeRecipeItemsMessage ?? "Remove all items from {recipe}?")
              .replaceAll("{recipe}", group.recipeName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations?.remove ?? "Remove"),
          ),
        ],
      ),
    );

    if (result == true) {
      await widget.controller.removeRecipeItems(group.recipeId);
    }
  }
}

class _RecipeGroupCard extends StatelessWidget {
  const _RecipeGroupCard({
    required this.group,
    required this.controller,
    required this.onRemoveRecipe,
  });

  final GroupedShoppingItems group;
  final ShoppingListController controller;
  final VoidCallback onRemoveRecipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe header
          InkWell(
            onTap: () {
              // Could navigate to recipe detail
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (group.recipeImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        buildImageUrl(group.recipeImage!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.recipeName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${group.checkedCount}/${group.totalCount} items",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (group.allChecked)
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  else if (group.someChecked)
                    Icon(
                      Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onSelected: (value) {
                      if (value == "check_all") {
                        controller.toggleRecipeGroup(group.recipeId, true);
                      } else if (value == "uncheck_all") {
                        controller.toggleRecipeGroup(group.recipeId, false);
                      } else if (value == "remove") {
                        onRemoveRecipe();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "check_all",
                        child: Row(
                          children: [
                            const Icon(Icons.check_box, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context)?.checkAll ?? "Check All"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "uncheck_all",
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context)?.uncheckAll ?? "Uncheck All"),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: "remove",
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)?.removeRecipe ?? "Remove Recipe",
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Items list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: group.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = group.items[index];
              return _ShoppingListItemTile(
                item: item,
                onToggle: () => controller.toggleItem(item.id),
                onRemove: () => controller.removeItem(item.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShoppingListItemTile extends StatelessWidget {
  const _ShoppingListItemTile({
    required this.item,
    required this.onToggle,
    required this.onRemove,
  });

  final ShoppingListItem item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onRemove(),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: item.isChecked
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: item.isChecked,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.displayText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    color: item.isChecked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
