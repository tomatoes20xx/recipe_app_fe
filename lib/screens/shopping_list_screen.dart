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
import "../recipes/create/ingredient_row.dart" show ingredientUnitsFor;
import "../theme/token_input.dart";
import "../widgets/common/skeletons.dart";
import "../widgets/common/token_widgets.dart";
import "shell_navigation.dart";
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

class _ShoppingListScreenState extends State<ShoppingListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// "By ingredient" instead of "By recipe" / "As added", per tab.
  bool _recipesByIngredient = false;
  bool _manualByIngredient = false;

  final TextEditingController _addName = TextEditingController();
  final TextEditingController _addAmount = TextEditingController();
  final FocusNode _addFocus = FocusNode();
  String? _addUnit;

  bool get _onManualTab => _tabs.index == 1;

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
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
    // Refresh shopping list data when screen is first entered
    // This ensures we see the latest state (e.g., items checked by collaborators)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.controller.isLoading && !widget.controller.isSyncing) {
        widget.controller.syncWithServer();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _addName.dispose();
    _addAmount.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  List<ShoppingListItem> get _currentItems =>
      _onManualTab ? widget.controller.manualItems : widget.controller.recipeItems;

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
            listenable: Listenable.merge([widget.controller, _tabs]),
            builder: (context, _) {
              final items = _currentItems;
              final syncing = widget.controller.isSyncing;
              final loggedIn = widget.auth?.isLoggedIn == true;
              // Sharing covers recipe items only, so it lives on the Recipes tab.
              final canShare = !_onManualTab && loggedIn;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                  if (!syncing && canShare && items.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: _onShareTap,
                      tooltip: localizations?.shareShoppingList ?? "Share Shopping List",
                    ),
                  if (!syncing && items.any((i) => i.isChecked))
                    // Icon only: a text label squeezed the title.
                    IconButton(
                      onPressed: _showClearCheckedDialog,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      tooltip: localizations?.clearChecked ?? "Clear",
                    ),
                  if (!syncing && items.isNotEmpty)
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
                        if (canShare && _sharedCount > 0) ...[
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
                          const PopupMenuDivider(),
                        ],
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
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          tabs: [
            Tab(text: localizations?.recipes ?? "Recipes"),
            Tab(text: localizations?.shoppingManualTab ?? "Manual"),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => TabBarView(
          controller: _tabs,
          children: [
            _buildTab(manual: false),
            _buildTab(manual: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({required bool manual}) {
    final localizations = AppLocalizations.of(context);
    final controller = widget.controller;
    final items = manual ? controller.manualItems : controller.recipeItems;
    final byIngredient = manual ? _manualByIngredient : _recipesByIngredient;

    final slivers = <Widget>[
      if (manual) SliverToBoxAdapter(child: _buildAddRow()),
    ];

    if (controller.isLoading && controller.items.isEmpty) {
      slivers.add(const SliverToBoxAdapter(child: ListRowSkeleton(leadingSize: 48)));
    } else if (items.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: manual
            ? EmptyStateWidget(
                icon: Icons.edit_note_rounded,
                title: localizations?.manualEmptyTitle ?? "No items yet",
                description: localizations?.manualEmptyBody ??
                    "Add things that aren't in a recipe, like milk or bread.",
                actionLabel: localizations?.addAnItem ?? "Add an item",
                actionIcon: Icons.add_rounded,
                onAction: () => _addFocus.requestFocus(),
              )
            : EmptyStateWidget(
                icon: Icons.shopping_cart_outlined,
                title: localizations?.emptyShoppingList ?? "Shopping list is empty",
                description: localizations?.emptyShoppingListMessage ??
                    "Add ingredients from recipes to create your shopping list",
                actionLabel: localizations?.exploreRecipes ?? "Explore recipes",
                actionIcon: Icons.explore_outlined,
                onAction: () => ShellNavigation.go(context, ShellRequest.home),
              ),
      ));
    } else {
      final checked = items.where((i) => i.isChecked).length;
      slivers.addAll([
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, manual ? 0 : 16, 16, 12),
            child: ProfileStatsCard(
              stats: [
                ProfileStat(value: items.length, label: localizations?.totalItems ?? 'Total items'),
                ProfileStat(value: checked, label: localizations?.checked ?? 'Checked'),
                ProfileStat(value: items.length - checked, label: localizations?.remaining ?? 'Remaining'),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                TokenChip(
                  label: manual ? (localizations?.asAdded ?? "As added") : (localizations?.byRecipe ?? "By recipe"),
                  selected: !byIngredient,
                  onTap: () => setState(() {
                    if (manual) {
                      _manualByIngredient = false;
                    } else {
                      _recipesByIngredient = false;
                    }
                  }),
                ),
                const SizedBox(width: 8),
                TokenChip(
                  label: localizations?.byIngredient ?? "By ingredient",
                  selected: byIngredient,
                  onTap: () => setState(() {
                    if (manual) {
                      _manualByIngredient = true;
                    } else {
                      _recipesByIngredient = true;
                    }
                  }),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: byIngredient
              ? SliverToBoxAdapter(
                  child: _MergedList(
                    rows: MergedShoppingRow.merge(items),
                    showRecipes: !manual,
                    controller: controller,
                  ),
                )
              : manual
                  ? SliverToBoxAdapter(child: _ManualList(items: items, controller: controller))
                  : SliverList.builder(
                      itemCount: controller.groupedItems.length,
                      itemBuilder: (context, index) {
                        final group = controller.groupedItems[index];
                        return _RecipeGroupCard(
                          group: group,
                          controller: controller,
                          apiClient: widget.apiClient,
                          auth: widget.auth,
                          onRemoveRecipe: () => _showRemoveRecipeDialog(group),
                        );
                      },
                    ),
        ),
      ]);
    }

    return RefreshIndicator(
      onRefresh: () => controller.syncWithServer(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  /// Name, optional amount and unit, and an add button: the Manual tab's top.
  Widget _buildAddRow() {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final units = ingredientUnitsFor(l?.locale.languageCode ?? "en");

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          TextField(
            controller: _addName,
            focusNode: _addFocus,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            style: tokenFieldStyle(t),
            decoration: tokenInputDecoration(t, hint: l?.manualItemHint ?? "Add an item, e.g. milk"),
            onSubmitted: (_) => _addManualItem(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _addAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: tokenFieldStyle(t),
                  decoration: tokenInputDecoration(t, hint: l?.amountHint ?? "Amount"),
                  onSubmitted: (_) => _addManualItem(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PopupMenuButton<String>(
                  initialValue: _addUnit ?? "",
                  onSelected: (unit) => setState(() => _addUnit = unit.isEmpty ? null : unit),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: "", child: Text(l?.noUnit ?? "No unit")),
                    for (final unit in units) PopupMenuItem(value: unit, child: Text(unit)),
                  ],
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: t.field, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _addUnit ?? (l?.unit ?? "Unit"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: _addUnit == null ? t.ink2 : t.ink),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, size: 20, color: t.ink2),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addManualItem,
                tooltip: l?.add ?? "Add",
                style: IconButton.styleFrom(
                  backgroundColor: t.fill,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addManualItem() async {
    final name = _addName.text.trim();
    if (name.isEmpty) {
      _addFocus.requestFocus();
      return;
    }
    final auth = widget.auth;
    if (auth == null || !await requireAccount(context, auth, AccountReason.shoppingList)) return;
    final amount = double.tryParse(_addAmount.text.trim().replaceAll(",", "."));
    await widget.controller.addManualItem(name: name, quantity: amount, unit: _addUnit);
    if (!mounted) return;
    _addName.clear();
    _addAmount.clear();
    // Ready for the next item.
    _addFocus.requestFocus();
  }

  Future<void> _onShareTap() async {
    final auth = widget.auth;
    if (auth == null || !await requireAccount(context, auth, AccountReason.share)) return;
    if (!mounted) return;

    // First: Select recipes to share (manual items aren't shared)
    await showRecipeSelectionBottomSheet(
      context: context,
      allItems: widget.controller.recipeItems,
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
          await api.revokeAllSharesWithUser(userId);

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

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Clears the checked items of the current tab.
  Future<void> _showClearCheckedDialog() async {
    final localizations = AppLocalizations.of(context);
    final manual = _onManualTab;
    if (await _confirm(
      title: localizations?.clearCheckedItems ?? "Clear checked items?",
      message: localizations?.clearCheckedItemsMessage ??
          "This will remove all checked items from your shopping list.",
      action: localizations?.clear ?? "Clear",
    )) {
      await widget.controller.clearCheckedItems(manual: manual);
    }
  }

  /// Clears every item of the current tab.
  Future<void> _showClearAllDialog() async {
    final localizations = AppLocalizations.of(context);
    final manual = _onManualTab;
    if (await _confirm(
      title: localizations?.clearAllItems ?? "Clear all items?",
      message: localizations?.clearAllItemsMessage ??
          "This will remove all items from your shopping list. This action cannot be undone.",
      action: localizations?.clearAll ?? "Clear All",
    )) {
      await widget.controller.clearAll(manual: manual);
    }
  }

  Future<void> _showRemoveRecipeDialog(GroupedShoppingItems group) async {
    final localizations = AppLocalizations.of(context);
    if (await _confirm(
      title: localizations?.removeRecipeItems ?? "Remove recipe items?",
      message: (localizations?.removeRecipeItemsMessage ?? "Remove all items from {recipe}?")
          .replaceAll("{recipe}", group.recipeName),
      action: localizations?.remove ?? "Remove",
    )) {
      await widget.controller.removeRecipeItems(group.recipeId);
    }
  }
}

/// The Manual tab's "As added" list: one card, newest first.
class _ManualList extends StatelessWidget {
  const _ManualList({required this.items, required this.controller});

  final List<ShoppingListItem> items;
  final ShoppingListController controller;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _ShoppingListItemTile(
                item: item,
                onToggle: () => controller.toggleItem(item.id),
                onRemove: () => controller.removeItem(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// "By ingredient": one row per name, amounts added up per unit. Ticking a
/// row ticks all its items; removing it asks first when it holds several.
class _MergedList extends StatelessWidget {
  const _MergedList({required this.rows, required this.showRecipes, required this.controller});

  final List<MergedShoppingRow> rows;

  /// Name the recipes under each row (the Recipes tab).
  final bool showRecipes;
  final ShoppingListController controller;

  String _amount(MergedShoppingRow row) {
    return [
      for (final entry in row.totals.entries)
        entry.key.isEmpty ? formatQuantity(entry.value) : "${formatQuantity(entry.value)} ${entry.key}",
    ].join(" + ");
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Dismissible(
              key: ValueKey("merged_${row.itemIds.join("_")}"),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                if (row.items.length == 1) return true;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(l?.removeMergedItems(row.name, row.items.length) ??
                        "Remove ${row.name} (${row.items.length} items)?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(l?.cancel ?? "Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                        child: Text(l?.remove ?? "Remove"),
                      ),
                    ],
                  ),
                );
                return ok == true;
              },
              onDismissed: (_) => controller.removeItems(row.itemIds),
              child: InkWell(
                onTap: () => controller.toggleItems(row.itemIds, !row.allChecked),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: row.allChecked,
                          onChanged: (_) => controller.toggleItems(row.itemIds, !row.allChecked),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: row.allChecked ? t.ink2 : t.ink,
                                decoration: row.allChecked ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (showRecipes && row.recipeNames.isNotEmpty)
                              Text(
                                row.recipeNames.join(", "),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: t.ink2),
                              ),
                          ],
                        ),
                      ),
                      if (row.totals.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          _amount(row),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: row.allChecked ? t.ink2 : t.brandInk,
                            decoration: row.allChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
                    borderRadius: BorderRadius.circular(6),
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
