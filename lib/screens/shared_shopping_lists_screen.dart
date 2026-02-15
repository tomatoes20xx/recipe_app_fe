import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../shopping/shared_shopping_lists_controller.dart";
import "../shopping/shopping_list_api.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";
import "shared_user_shopping_list_screen.dart";

class SharedShoppingListsScreen extends StatefulWidget {
  const SharedShoppingListsScreen({
    super.key,
    required this.apiClient,
    required this.auth,
  });

  final ApiClient apiClient;
  final AuthController? auth;

  @override
  State<SharedShoppingListsScreen> createState() => _SharedShoppingListsScreenState();
}

class _SharedShoppingListsScreenState extends State<SharedShoppingListsScreen> {
  late final SharedShoppingListsController controller;

  @override
  void initState() {
    super.initState();
    controller = SharedShoppingListsController(
      shoppingListApi: ShoppingListApi(widget.apiClient),
    );
    controller.addListener(_onChanged);
    controller.loadLists();
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

  Future<bool?> _showDeleteConfirmation(String ownerName) async {
    final localizations = AppLocalizations.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeSharedList ?? "Remove Shared List"),
        content: Text(
          localizations?.removeSharedListConfirm ??
              "Remove all shared items from $ownerName? This won't affect the owner's list.",
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
  }

  Future<void> _dismissAllFromUser(String ownerId) async {
    final localizations = AppLocalizations.of(context);
    try {
      await controller.dismissAllFromUser(ownerId);
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.sharedShoppingLists ?? "Shared Shopping Lists"),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: Builder(
          builder: (context) {
            if (controller.isLoading && controller.lists.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null && controller.lists.isEmpty) {
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

            if (controller.lists.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.shopping_basket_outlined,
                title: localizations?.noSharedShoppingLists ?? "No shopping lists shared with you yet",
                description: localizations?.listsSharedWithYou ??
                    "When someone shares a shopping list with you, it will appear here",
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: controller.lists.length,
              itemBuilder: (context, index) {
                final list = controller.lists[index];
                return Dismissible(
                  key: Key('shared_list_${list.ownerId}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await _showDeleteConfirmation(
                      list.ownerDisplayName ?? list.ownerUsername,
                    );
                  },
                  onDismissed: (direction) async {
                    await _dismissAllFromUser(list.ownerId);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SharedUserShoppingListScreen(
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                            userShares: list,
                            controller: controller,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Owner avatar
                          buildUserAvatar(
                            context,
                            list.ownerAvatarUrl,
                            list.ownerUsername,
                            radius: 24,
                          ),
                          const SizedBox(width: 16),

                          // List info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${localizations?.shoppingListOf ?? "Shopping list of"} ${list.ownerDisplayName ?? list.ownerUsername}",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "@${list.ownerUsername}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Share type badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: list.isCollaborative
                                            ? theme.colorScheme.primaryContainer
                                            : theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            list.isCollaborative ? Icons.edit : Icons.visibility,
                                            size: 14,
                                            color: list.isCollaborative
                                                ? theme.colorScheme.onPrimaryContainer
                                                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            list.isCollaborative
                                                ? (localizations?.collaborative ?? "Collaborative")
                                                : (localizations?.readOnly ?? "Read Only"),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: list.isCollaborative
                                                  ? theme.colorScheme.onPrimaryContainer
                                                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Item count
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${list.totalItems} ${list.totalItems == 1 ? 'item' : 'items'}",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatRelativeTime(context, list.latestSharedAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Chevron
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
