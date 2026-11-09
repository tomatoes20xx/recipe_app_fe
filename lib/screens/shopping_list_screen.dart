import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../sharing/sharing_models.dart";
import "../shopping/shopping_list_api.dart";
import "../shopping/shopping_list_controller.dart";
import "../shopping/shopping_list_models.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../theme/app_tokens.dart";
import "../widgets/common/profile_stats_card.dart";
import "../widgets/common/recipe_grid_tile.dart";
import "../widgets/empty_state_widget.dart";
import "../widgets/sharing/follower_selection_bottom_sheet.dart";
import "../widgets/sharing/recipe_selection_bottom_sheet.dart";
import "../widgets/sharing/shared_with_bottom_sheet.dart";

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({
    super.key,
    required this.controller,
    required this.apiClient,
    required this.auth,
  });

  final ShoppingListController controller;
  final ApiClient apiClient;
  final AuthController? auth;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  /// Extract unique users who have access to any recipe in the shopping list
  List<SharedWithUser> _getSharedWithUsers() {
    final Map<String, SharedWithUser> uniqueUsers = {};

    for (final item in widget.controller.items) {
      for (final user in item.sharedWith) {
        uniqueUsers[user.userId] = user;
      }
    }

    return uniqueUsers.values.toList();
  }

  /// Get count of unique users who have access
  int get _sharedCount => _getSharedWithUsers().length;

  @override
  void initState() {
    super.initState();
    // Refresh shopping list data when screen is first entered
    // This ensures we see the latest state (e.g., items checked by collaborators)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.controller.isLoading && !widget.controller.isSyncing) {
        widget.controller.syncWithServer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations?.shoppingList ?? "Shopping List"),
              if (widget.controller.isSyncing)
                Text(
                  localizations?.syncing ?? "Syncing…",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          if (!widget.controller.isSyncing && widget.auth?.isLoggedIn == true)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _onShareTap,
              tooltip: localizations?.shareShoppingList ?? "Share Shopping List",
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
                if (value == "manage_sharing") {
                  _showManageAllSharing();
                } else if (value == "clear_all") {
                  _showClearAllDialog();
                }
              },
              itemBuilder: (context) => [
                if (widget.auth?.isLoggedIn == true && _sharedCount > 0)
                  PopupMenuItem(
                    value: "manage_sharing",
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          localizations?.manageSharing ?? "Manage Sharing",
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                if (widget.auth?.isLoggedIn == true && _sharedCount > 0)
                  const PopupMenuDivider(),
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
          ],  // Close children array of Row
        ),    // Close Row
      ),      // Close ListenableBuilder
    ],        // Close actions array
  ),          // Close AppBar
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
    final groups = widget.controller.groupedItems;

    return CustomScrollView(
      slivers: [
        // Stats: the same card as the profiles' stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProfileStatsCard(
              stats: [
                ProfileStat(value: widget.controller.totalCount, label: localizations?.totalItems ?? 'Total items'),
                ProfileStat(value: widget.controller.checkedCount, label: localizations?.checked ?? 'Checked'),
                ProfileStat(value: widget.controller.uncheckedCount, label: localizations?.remaining ?? 'Remaining'),
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
                  apiClient: widget.apiClient,
                  auth: widget.auth,
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

  Future<void> _onShareTap() async {
    final auth = widget.auth;
    if (auth == null || !await requireAccount(context, auth, AccountReason.share)) return;
    if (!mounted) return;

    // First: Select recipes to share
    await showRecipeSelectionBottomSheet(
      context: context,
      allItems: widget.controller.items,
      onRecipesSelected: (selectedRecipeIds) async {
        // Second: Select followers and share type
        await showFollowerSelectionBottomSheet(
          context: context,
          apiClient: widget.apiClient,
          auth: widget.auth!,
          alreadySharedWith: [], // TODO: Track per-recipe shares
          showShareTypeSelector: true,
          onShare: (userIds, shareType) async {
            try {
              final api = ShoppingListApi(widget.apiClient);
              await api.shareRecipeIngredients(
                userIds: userIds,
                recipeIds: selectedRecipeIds,
                shareType: shareType ?? "read_only",
              );
              if (mounted) {
                final localizations = AppLocalizations.of(context);
                ErrorUtils.showSuccess(
                  context,
                  localizations?.shoppingListSharedSuccess ?? "Recipes shared successfully!",
                );
              }
            } catch (e) {
              if (mounted) {
                ErrorUtils.showError(context, e);
              }
            }
          },
        );
      },
    );
  }

  Future<void> _showManageAllSharing() async {
    if (!(widget.auth?.isLoggedIn ?? false)) return;

    await showSharedWithBottomSheet(
      context: context,
      sharedWith: _getSharedWithUsers(),
      isLoading: false,
      onUnshare: (userId) async {
        try {
          final api = ShoppingListApi(widget.apiClient);

          // Revoke ALL shares with this user (bulk delete)
          final deletedCount = await api.revokeAllSharesWithUser(userId);

          // Refresh the shopping list to get updated sharing info
          await widget.controller.syncWithServer();

          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ErrorUtils.showSuccess(
              context,
              localizations?.unshareConfirmation ?? "Access removed successfully",
            );
          }
        } catch (e) {
          if (mounted) {
            ErrorUtils.showError(context, e);
          }
        }
      },
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
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

class _RecipeGroupCard extends StatefulWidget {
  const _RecipeGroupCard({
    required this.group,
    required this.controller,
    required this.onRemoveRecipe,
    required this.apiClient,
    this.auth,
  });

  final GroupedShoppingItems group;
  final ShoppingListController controller;
  final VoidCallback onRemoveRecipe;
  final ApiClient apiClient;
  final AuthController? auth;

  @override
  State<_RecipeGroupCard> createState() => _RecipeGroupCardState();
}

class _RecipeGroupCardState extends State<_RecipeGroupCard> {

  /// Get users who have access to this specific recipe
  List<SharedWithUser> _getSharedUsers() {
    final Map<String, SharedWithUser> uniqueUsers = {};

    // Get sharedWith from any item in this recipe group
    for (final item in widget.group.items) {
      for (final user in item.sharedWith) {
        uniqueUsers[user.userId] = user;
      }
    }

    return uniqueUsers.values.toList();
  }

  Future<void> _showManageSharing() async {
    final sharedUsers = _getSharedUsers();

    if (sharedUsers.isEmpty) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.recipeNotSharedWithAnyone ?? "This recipe is not shared with anyone");
      return;
    }

    await showSharedWithBottomSheet(
      context: context,
      sharedWith: sharedUsers,
      isLoading: false,
      onUnshare: (userId) async {
        try {
          final api = ShoppingListApi(widget.apiClient);

          // Get shareId from the inline sharedWith data
          String? shareId;

          // Look through items in this recipe group to find the shareId
          for (final item in widget.group.items) {
            try {
              final sharedUser = item.sharedWith.firstWhere(
                (u) => u.userId == userId,
              );

              if (sharedUser.shareId != null) {
                shareId = sharedUser.shareId;
                break;
              }
            } catch (e) {
              // User not found in this item's sharedWith array, continue to next item
              continue;
            }
          }

          if (shareId == null) {
            throw Exception("Could not find share ID for this user");
          }

          // Revoke this specific recipe share
          await api.revokeRecipeShare(shareId);

          // Refresh the shopping list to get updated sharing info
          await widget.controller.syncWithServer();

          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ErrorUtils.showSuccess(
              context,
              localizations?.unshareConfirmation ?? "Access removed successfully",
            );
            Navigator.of(context).pop(); // Close the bottom sheet
          }
        } catch (e) {
          if (mounted) {
            ErrorUtils.showError(context, e);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final sharedCount = _getSharedUsers().length;

    final t = AppTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe header
          InkWell(
            onTap: widget.group.recipeId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(
                          recipeId: widget.group.recipeId,
                          apiClient: widget.apiClient,
                          auth: widget.auth,
                          shoppingListController: widget.controller,
                        ),
                      ),
                    ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
              child: Row(
                children: [
                  RecipeThumb(imageUrl: widget.group.recipeImage, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.recipeName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              localizations?.shoppingItemsCount(widget.group.checkedCount, widget.group.totalCount) ?? "${widget.group.checkedCount}/${widget.group.totalCount} items",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            if (sharedCount > 0) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$sharedCount",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.group.allChecked)
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  else if (widget.group.someChecked)
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
                        widget.controller.toggleRecipeGroup(widget.group.recipeId, true);
                      } else if (value == "uncheck_all") {
                        widget.controller.toggleRecipeGroup(widget.group.recipeId, false);
                      } else if (value == "manage_sharing") {
                        _showManageSharing();
                      } else if (value == "remove") {
                        widget.onRemoveRecipe();
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
                      if (sharedCount > 0) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: "manage_sharing",
                          child: Row(
                            children: [
                              Icon(Icons.people_outline, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context)?.manageSharing ?? "Manage Sharing",
                                style: TextStyle(color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
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
            itemCount: widget.group.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = widget.group.items[index];
              return _ShoppingListItemTile(
                item: item,
                onToggle: () => widget.controller.toggleItem(item.id),
                onRemove: () => widget.controller.removeItem(item.id),
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
                ? theme.colorScheme.surfaceContainerHighest
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
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    color: item.isChecked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
              if (item.quantity != null || item.unit != null)
                Text(
                  [
                    if (item.quantity != null) formatQuantity(item.quantity!),
                    if (item.unit != null) item.unit!,
                  ].join(' '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    color: item.isChecked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
