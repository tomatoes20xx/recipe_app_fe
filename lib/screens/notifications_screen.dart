import "package:flutter/material.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../notifications/notification_api.dart";
import "../notifications/notification_controller.dart";
import "../notifications/notification_models.dart" as notification_models;
import "../recipes/recipe_detail_screen.dart";
import "../screens/profile_screen.dart";
import "../screens/shared_shopping_lists_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.notificationController,
    required this.shoppingListController,
  });

  final ApiClient apiClient;
  final AuthController auth;
  final NotificationController notificationController;
  final ShoppingListController shoppingListController;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    widget.notificationController.addListener(_onControllerChanged);
    // Defer loading until after the build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always refresh notifications when entering this screen
      if (widget.notificationController.items.isEmpty) {
        widget.notificationController.loadInitial();
      } else {
        // If already loaded, just refresh to get latest data
        widget.notificationController.refresh(unreadOnly: _showUnreadOnly);
      }
    });
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.notificationController.removeListener(_onControllerChanged);
    // Don't dispose the controller - it's owned by FeedShellScreen
    super.dispose();
  }

  String _formatDate(DateTime date, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return localizations?.justNow ?? "Just now";
        }
        final minutesAgo = localizations?.minutesAgo ?? "m ago";
        return "${difference.inMinutes}$minutesAgo";
      }
      final hoursAgo = localizations?.hoursAgo ?? "h ago";
      return "${difference.inHours}$hoursAgo";
    } else if (difference.inDays == 1) {
      return localizations?.yesterday ?? "Yesterday";
    } else if (difference.inDays < 7) {
      final daysAgo = localizations?.daysAgo ?? "d ago";
      return "${difference.inDays}$daysAgo";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  IconData _getNotificationIcon(notification_models.NotificationType type) {
    switch (type) {
      case notification_models.NotificationType.follow:
        return Icons.person_add;
      case notification_models.NotificationType.like:
        return Icons.favorite;
      case notification_models.NotificationType.comment:
        return Icons.comment;
      case notification_models.NotificationType.bookmark:
        return Icons.bookmark;
      case notification_models.NotificationType.recipe:
        return Icons.restaurant_menu;
      case notification_models.NotificationType.recipeShare:
        return Icons.share;
      case notification_models.NotificationType.shoppingListShare:
        return Icons.shopping_basket;
      case notification_models.NotificationType.unknown:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(notification_models.NotificationType type, BuildContext context) {
    switch (type) {
      case notification_models.NotificationType.follow:
        return Colors.blue;
      case notification_models.NotificationType.like:
        return Colors.red;
      case notification_models.NotificationType.comment:
        return Colors.orange;
      case notification_models.NotificationType.bookmark:
        return Colors.purple;
      case notification_models.NotificationType.recipe:
        return Colors.green;
      case notification_models.NotificationType.recipeShare:
        return Colors.teal;
      case notification_models.NotificationType.shoppingListShare:
        return Colors.indigo;
      case notification_models.NotificationType.unknown:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getNotificationTitle(notification_models.Notification notification, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // Use display name if available, otherwise fall back to username
    final actor = notification.actorDisplayName ?? notification.actorUsername ?? "Someone";
    final recipe = notification.recipeTitle ?? "";

    switch (notification.type) {
      case notification_models.NotificationType.follow:
        return localizations?.notificationFollowed(actor) ?? "$actor started following you";

      case notification_models.NotificationType.like:
        if (recipe.isNotEmpty) {
          return localizations?.notificationLikedRecipe(actor, recipe) ?? "$actor liked \"$recipe\"";
        }
        return localizations?.notificationLiked(actor) ?? "$actor liked your recipe";

      case notification_models.NotificationType.comment:
        if (recipe.isNotEmpty) {
          return localizations?.notificationCommentedRecipe(actor, recipe) ?? "$actor commented on \"$recipe\"";
        }
        return localizations?.notificationCommented(actor) ?? "$actor commented on your recipe";

      case notification_models.NotificationType.bookmark:
        if (recipe.isNotEmpty) {
          return localizations?.notificationBookmarkedRecipe(actor, recipe) ?? "$actor bookmarked \"$recipe\"";
        }
        return localizations?.notificationBookmarked(actor) ?? "$actor bookmarked your recipe";

      case notification_models.NotificationType.recipe:
        if (recipe.isNotEmpty) {
          return localizations?.notificationPostedRecipe(actor, recipe) ?? "$actor posted \"$recipe\"";
        }
        return localizations?.notificationLiked(actor) ?? "$actor posted a new recipe";

      case notification_models.NotificationType.recipeShare:
        if (recipe.isNotEmpty) {
          return localizations?.notificationSharedRecipe(actor, recipe) ?? "$actor shared \"$recipe\" with you";
        }
        return "$actor shared a recipe with you";

      case notification_models.NotificationType.shoppingListShare:
        return localizations?.notificationSharedShoppingList(actor) ?? "$actor shared a shopping list with you";

      case notification_models.NotificationType.unknown:
        return notification.message ?? notification.title ?? "New notification";
    }
  }

  String? _getNotificationMessage(notification_models.Notification notification) {
    // Messages are now combined into the title, so return null
    return null;
  }

  Future<void> _handleNotificationTap(notification_models.Notification notification) async {
    // Mark as read if unread
    if (!notification.isRead) {
      try {
        await widget.notificationController.markAsRead(notification.id);
      } catch (e) {
        if (!mounted) return;
        ErrorUtils.showError(context, e);
        return;
      }
    }

    // Navigate based on notification type
    if (!mounted) return;
    switch (notification.type) {
      case notification_models.NotificationType.follow:
        if (notification.actorUsername != null) {
          // If viewing own profile, pass null to show edit functionality
          final isOwnProfile = widget.auth.me?["username"]?.toString() == notification.actorUsername;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                auth: widget.auth,
                apiClient: widget.apiClient,
                shoppingListController: widget.shoppingListController,
                username: isOwnProfile ? null : notification.actorUsername!,
              ),
            ),
          );
        }
        break;

      case notification_models.NotificationType.like:
      case notification_models.NotificationType.comment:
      case notification_models.NotificationType.bookmark:
        if (notification.recipeId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(
                recipeId: notification.recipeId!,
                apiClient: widget.apiClient,
                auth: widget.auth,
                shoppingListController: widget.shoppingListController,
              ),
            ),
          );
        }
        break;

      case notification_models.NotificationType.recipe:
      case notification_models.NotificationType.recipeShare:
        if (notification.recipeId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(
                recipeId: notification.recipeId!,
                apiClient: widget.apiClient,
                auth: widget.auth,
                shoppingListController: widget.shoppingListController,
              ),
            ),
          );
        }
        break;

      case notification_models.NotificationType.shoppingListShare:
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SharedShoppingListsScreen(
                apiClient: widget.apiClient,
                auth: widget.auth,
              ),
            ),
          );
        }
        break;

      case notification_models.NotificationType.unknown:
        // Do nothing for unknown types
        break;
    }
  }

  Future<bool> _confirmDeleteNotification() async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.deleteNotificationTitle ?? "Delete notification?"),
        content: Text(localizations?.deleteNotificationMessage ?? "Are you sure you want to delete this notification?"),
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
            child: Text(localizations?.delete ?? "Delete"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteNotification(notification_models.Notification notification) async {
    final confirmed = await _confirmDeleteNotification();
    if (!confirmed) return;

    try {
      await widget.notificationController.deleteNotification(notification.id);
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showSuccess(context, localizations?.notificationDeleted ?? "Notification deleted");
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showError(context, e);
    }
  }

  Future<bool> _confirmClearAllNotifications() async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.clearAllNotificationsTitle ?? "Clear all notifications?"),
        content: Text(localizations?.clearAllNotificationsMessage ?? "Are you sure you want to delete all notifications? This action cannot be undone."),
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
            child: Text(localizations?.clearAll ?? "Clear all"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleClearAllNotifications() async {
    final confirmed = await _confirmClearAllNotifications();
    if (!confirmed) return;

    try {
      final deleted = await widget.notificationController.deleteAllNotifications();
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      final message = localizations?.notificationsCleared ?? "Cleared $deleted notification(s)";
      ErrorUtils.showSuccess(context, message.replaceAll("{count}", deleted.toString()));
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.notifications ?? "Notifications");
          },
        ),
        actions: [
          if (widget.notificationController.unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                try {
                  await widget.notificationController.markAllAsRead();
                  if (!mounted) return;
                  ErrorUtils.showSuccess(this.context, "All notifications marked as read");
                } catch (e) {
                  if (!mounted) return;
                  ErrorUtils.showError(this.context, e);
                }
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(localizations?.markAllRead ?? "Mark all read");
                },
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == "clear_all") {
                await _handleClearAllNotifications();
              } else {
                setState(() {
                  _showUnreadOnly = value == "unread";
                });
                widget.notificationController.loadInitial(unreadOnly: _showUnreadOnly);
              }
            },
            itemBuilder: (context) {
              final localizations = AppLocalizations.of(context);
              return [
                PopupMenuItem(
                  value: "all",
                  child: Row(
                    children: [
                      const Icon(Icons.list, size: 18),
                      const SizedBox(width: 8),
                      Text(localizations?.allNotifications ?? "All notifications"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: "unread",
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread, size: 18),
                      const SizedBox(width: 8),
                      Text(localizations?.unreadOnly ?? "Unread only"),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: "clear_all",
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        localizations?.clearAllNotifications ?? "Clear all notifications",
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                _showUnreadOnly ? Icons.mark_email_unread : Icons.filter_list,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => widget.notificationController.refresh(unreadOnly: _showUnreadOnly),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.notificationController.isLoading && widget.notificationController.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.notificationController.error != null && widget.notificationController.items.isEmpty) {
      return ErrorStateWidget(
        message: ErrorUtils.getUserFriendlyMessage(widget.notificationController.error!, context),
        onRetry: () => widget.notificationController.loadInitial(unreadOnly: _showUnreadOnly),
      );
    }

    if (widget.notificationController.items.isEmpty) {
      return EmptyStateWidget(
        icon: _showUnreadOnly ? Icons.mark_email_read : Icons.notifications_none,
        title: _showUnreadOnly ? "No unread notifications" : "No notifications",
        description: _showUnreadOnly
            ? "You're all caught up!"
            : "You'll see notifications here when someone interacts with your content",
        titleStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        descriptionStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: widget.notificationController.items.length + (widget.notificationController.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.notificationController.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final notification = widget.notificationController.items[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(notification_models.Notification notification) {
    final iconColor = _getNotificationColor(notification.type, context);
    final icon = _getNotificationIcon(notification.type);
    final title = _getNotificationTitle(notification, context);
    final message = _getNotificationMessage(notification);
    final date = _formatDate(notification.createdAt, context);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDeleteNotification();
      },
      onDismissed: (direction) async {
        try {
          await widget.notificationController.deleteNotification(notification.id);
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ErrorUtils.showSuccess(context, localizations?.notificationDeleted ?? "Notification deleted");
          }
        } catch (e) {
          if (mounted) {
            ErrorUtils.showError(context, e);
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
            border: Border(
              left: BorderSide(
                color: notification.isRead
                    ? Colors.transparent
                    : iconColor,
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or icon
              if (notification.actorAvatarUrl != null)
                buildUserAvatar(
                  context,
                  notification.actorAvatarUrl,
                  notification.actorUsername ?? "",
                  radius: 24,
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
