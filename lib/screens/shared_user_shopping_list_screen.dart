import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../sharing/sharing_models.dart";
import "../shopping/shared_shopping_lists_controller.dart";
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
    required this.userShares,
    required this.controller,
  });

  final ApiClient apiClient;
  final AuthController? auth;
  final UserShares userShares;
  final SharedShoppingListsController controller;

  @override
  State<SharedUserShoppingListScreen> createState() => _SharedUserShoppingListScreenState();
}

class _SharedUserShoppingListScreenState extends State<SharedUserShoppingListScreen> {
  late ShoppingListApi shoppingListApi;

  @override
  void initState() {
    super.initState();
    shoppingListApi = ShoppingListApi(widget.apiClient);
    // Listen to controller updates
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleItem(String shareId, String itemId, bool currentValue) async {
    // Get current user shares
    final userSharesIndex = widget.controller.lists.indexWhere((u) => u.ownerId == widget.userShares.ownerId);
    if (userSharesIndex == -1) return;

    final currentUserShares = widget.controller.lists[userSharesIndex];
    final shareIndex = currentUserShares.shares.indexWhere((s) => s.shareId == shareId);
    if (shareIndex == -1) return;

    final share = currentUserShares.shares[shareIndex];

    if (!share.isCollaborative) {
      ErrorUtils.showError(
        context,
        AppLocalizations.of(context)?.cannotModifyReadOnly ??
            "This list is view-only. You cannot modify items.",
      );
      return;
    }

    // Find the item
    final itemIndex = share.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;

    final oldItem = share.items[itemIndex];
    final newCheckedState = !currentValue;

    // OPTIMISTIC UPDATE: Update local state immediately
    final updatedItem = oldItem.copyWith(isChecked: newCheckedState);
    final updatedItems = List<ShoppingListItem>.from(share.items);
    updatedItems[itemIndex] = updatedItem;

    final updatedShare = SharedRecipeShoppingList(
      shareId: share.shareId,
      shareType: share.shareType,
      recipeIds: share.recipeIds,
      ownerId: share.ownerId,
      ownerUsername: share.ownerUsername,
      ownerDisplayName: share.ownerDisplayName,
      ownerAvatarUrl: share.ownerAvatarUrl,
      sharedAt: share.sharedAt,
      items: updatedItems,
    );

    final updatedShares = List<SharedRecipeShoppingList>.from(currentUserShares.shares);
    updatedShares[shareIndex] = updatedShare;

    final updatedUserShares = UserShares(
      ownerId: currentUserShares.ownerId,
      ownerUsername: currentUserShares.ownerUsername,
      ownerDisplayName: currentUserShares.ownerDisplayName,
      ownerAvatarUrl: currentUserShares.ownerAvatarUrl,
      latestSharedAt: currentUserShares.latestSharedAt,
      totalItems: currentUserShares.totalItems,
      shares: updatedShares,
    );

    // Update controller's list
    widget.controller.lists[userSharesIndex] = updatedUserShares;

    // Notify controller to trigger rebuild
    widget.controller.notifyUpdate();

    // Now call backend in background
    try {
      await shoppingListApi.updateCollaborativeRecipeItem(
        userId: widget.userShares.ownerId,
        recipeId: oldItem.recipeId ?? "",
        itemId: itemId,
        isChecked: newCheckedState,
      );
    } catch (e) {
      // ROLLBACK on error
      final rolledBackShares = List<SharedRecipeShoppingList>.from(currentUserShares.shares);
      rolledBackShares[shareIndex] = share; // Restore original share

      final rolledBackUserShares = UserShares(
        ownerId: currentUserShares.ownerId,
        ownerUsername: currentUserShares.ownerUsername,
        ownerDisplayName: currentUserShares.ownerDisplayName,
        ownerAvatarUrl: currentUserShares.ownerAvatarUrl,
        latestSharedAt: currentUserShares.latestSharedAt,
        totalItems: currentUserShares.totalItems,
        shares: rolledBackShares,
      );

      widget.controller.lists[userSharesIndex] = rolledBackUserShares;

      if (mounted) {
        widget.controller.notifyUpdate();
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _deleteRecipeGroup(String shareId, String recipeName) async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeSharedRecipe ?? "Remove Shared Recipe"),
        content: Text(
          "Remove \"$recipeName\" from your shared lists? This won't affect the owner's list.",
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
        await widget.controller.dismissShare(shareId);
        // build() handles popping if no shares remain for this user
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

  Map<String, List<MapEntry<String, ShoppingListItem>>> _groupItemsByRecipe(UserShares freshUserShares) {
    final Map<String, List<MapEntry<String, ShoppingListItem>>> grouped = {};

    for (final share in freshUserShares.shares) {
      for (final item in share.items) {
        final key = item.recipeId ?? "__no_recipe__";
        grouped.putIfAbsent(key, () => []).add(MapEntry(share.shareId, item));
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Get fresh data from controller — may be null if all shares were dismissed
    final freshUserShares = widget.controller.lists
        .cast<UserShares?>()
        .firstWhere((u) => u?.ownerId == widget.userShares.ownerId, orElse: () => null);

    if (freshUserShares == null) {
      // All shares from this user were dismissed; pop on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final groupedItems = _groupItemsByRecipe(freshUserShares);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations?.shoppingList ?? "Shopping List"),
            Text(
              "@${freshUserShares.ownerUsername}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: groupedItems.isEmpty
          ? EmptyStateWidget(
              icon: Icons.shopping_cart_outlined,
              title: localizations?.emptyShoppingList ?? "Shopping list is empty",
              description: localizations?.emptyShoppingListMessage ??
                  "Add ingredients from recipes to create your shopping list",
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: freshUserShares.isCollaborative
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        freshUserShares.isCollaborative ? Icons.edit : Icons.visibility,
                        color: freshUserShares.isCollaborative
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          freshUserShares.isCollaborative
                              ? (localizations?.canCheckItemsCollaborative ??
                                  "You can check/uncheck items to help manage this list.")
                              : (localizations?.cannotModifyReadOnly ??
                                  "This list is view-only. You cannot modify items."),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: freshUserShares.isCollaborative
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Grouped items by recipe
                ...groupedItems.entries.map((entry) {
                  final recipeId = entry.key;
                  final itemEntries = entry.value;
                  final firstItem = itemEntries.first.value;
                  final recipeName = firstItem.recipeName;
                  final shareId = itemEntries.first.key;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipe header with delete button
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
                                if (firstItem.recipeImage != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      buildImageUrl(firstItem.recipeImage!),
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                if (firstItem.recipeImage != null) const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    recipeName ?? "Recipe",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${itemEntries.where((e) => e.value.isChecked).length}/${itemEntries.length}",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  iconSize: 20,
                                  color: theme.colorScheme.error,
                                  onPressed: () => _deleteRecipeGroup(shareId, recipeName ?? "Recipe"),
                                ),
                              ],
                            ),
                          ),

                        // Items
                        ...itemEntries.map((entry) {
                          final shareId = entry.key;
                          final item = entry.value;
                          final share = widget.userShares.shares.firstWhere((s) => s.shareId == shareId);

                          return CheckboxListTile(
                            value: item.isChecked,
                            onChanged: share.isCollaborative
                                ? (_) => _toggleItem(shareId, item.id, item.isChecked)
                                : null,
                            enabled: share.isCollaborative,
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
            ),
    );
  }
}
