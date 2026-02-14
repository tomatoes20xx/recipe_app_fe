import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../shopping/shared_user_shopping_list_controller.dart";
import "../shopping/shopping_list_api.dart";
import "../shopping/shopping_list_models.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";

class SharedUserShoppingListScreen extends StatefulWidget {
  const SharedUserShoppingListScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.userId,
    required this.ownerUsername,
    required this.shareType,
  });

  final ApiClient apiClient;
  final AuthController? auth;
  final String userId;
  final String ownerUsername;
  final String shareType;

  @override
  State<SharedUserShoppingListScreen> createState() => _SharedUserShoppingListScreenState();
}

class _SharedUserShoppingListScreenState extends State<SharedUserShoppingListScreen> {
  late final SharedUserShoppingListController controller;

  @override
  void initState() {
    super.initState();
    controller = SharedUserShoppingListController(
      shoppingListApi: ShoppingListApi(widget.apiClient),
      userId: widget.userId,
      shareType: widget.shareType,
    );
    controller.addListener(_onChanged);
    controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  Future<void> _toggleItem(String itemId) async {
    if (!controller.canEdit) {
      ErrorUtils.showError(
        context,
        AppLocalizations.of(context)?.cannotModifyReadOnly ??
            "This list is view-only. You cannot modify items.",
      );
      return;
    }

    try {
      await controller.toggleItem(itemId);
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  Map<String, List<ShoppingListItem>> _groupItemsByRecipe(List<ShoppingListItem> items) {
    final Map<String, List<ShoppingListItem>> grouped = {};

    for (final item in items) {
      final key = item.recipeId ?? "__no_recipe__";
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped;
  }

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
            Text(
              "@${widget.ownerUsername}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: Builder(
          builder: (context) {
            if (controller.isLoading && controller.list == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null && controller.list == null) {
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

            if (controller.list == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final list = controller.list!;

            if (list.items.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.shopping_cart_outlined,
                title: localizations?.emptyShoppingList ?? "Shopping list is empty",
                description: localizations?.emptyShoppingListMessage ??
                    "Add ingredients from recipes to create your shopping list",
              );
            }

            final groupedItems = _groupItemsByRecipe(list.items);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: list.isCollaborative
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        list.isCollaborative ? Icons.edit : Icons.visibility,
                        color: list.isCollaborative
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          list.isCollaborative
                              ? (localizations?.canCheckItemsCollaborative ??
                                  "You can check/uncheck items to help manage this list.")
                              : (localizations?.cannotModifyReadOnly ??
                                  "This list is view-only. You cannot modify items."),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: list.isCollaborative
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.list,
                        label: localizations?.total ?? "Total",
                        value: list.itemCount.toString(),
                        color: theme.colorScheme.primary,
                      ),
                      _StatItem(
                        icon: Icons.check_circle,
                        label: localizations?.checked ?? "Checked",
                        value: list.checkedCount.toString(),
                        color: Colors.green,
                      ),
                      _StatItem(
                        icon: Icons.radio_button_unchecked,
                        label: localizations?.remaining ?? "Remaining",
                        value: list.uncheckedCount.toString(),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),

                // Grouped items
                ...groupedItems.entries.map((entry) {
                  final recipeId = entry.key;
                  final items = entry.value;
                  final recipeName = items.first.recipeName;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipe header
                        if (recipeId != "__no_recipe__")
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (items.first.recipeImage != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      buildImageUrl(items.first.recipeImage!),
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                if (items.first.recipeImage != null) const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    recipeName ?? "Recipe",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${items.where((i) => i.isChecked).length}/${items.length}",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Items
                        ...items.map((item) {
                          return CheckboxListTile(
                            value: item.isChecked,
                            onChanged: controller.canEdit
                                ? (_) => _toggleItem(item.id)
                                : null,
                            enabled: controller.canEdit,
                            title: Text(
                              item.displayText,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                decoration: item.isChecked ? TextDecoration.lineThrough : null,
                                color: item.isChecked
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
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
}
