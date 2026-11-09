import "package:flutter/material.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../localization/app_localizations.dart";
import "../notifications/notification_controller.dart";
import "../notifications/notification_models.dart" as notification_models;
import "../recipes/recipe_detail_screen.dart";
import "../screens/profile_screen.dart";
import "../screens/shared_shopping_lists_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../theme/app_tokens.dart";
import "../widgets/common/profile_avatar.dart";
import "../widgets/common/skeletons.dart";
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.notificationController.addListener(_onControllerChanged);
    _wasSignedIn = widget.auth.isLoggedIn;
    widget.auth.addListener(_onAuthChanged);
    _scrollController.addListener(_onScroll);
    // Defer loading until after the build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guests have no notifications; the guest state asks them to sign up.
      if (!widget.auth.isLoggedIn) return;
      // Always refresh notifications when entering this screen
      if (widget.notificationController.items.isEmpty) {
        widget.notificationController.loadInitial();
      } else {
        // If already loaded, just refresh to get latest data
        widget.notificationController.refresh(unreadOnly: _showUnreadOnly);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      widget.notificationController.loadMore(unreadOnly: _showUnreadOnly);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  late bool _wasSignedIn;

  void _onAuthChanged() {
    final signedIn = widget.auth.isLoggedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    if (!mounted) return;
    setState(() {});
    if (signedIn) widget.notificationController.loadInitial(unreadOnly: _showUnreadOnly);
  }

  @override
  void dispose() {
    widget.notificationController.removeListener(_onControllerChanged);
    widget.auth.removeListener(_onAuthChanged);
    _scrollController.dispose();
    // Don't dispose the controller - it's owned by FeedShellScreen
    super.dispose();
  }

  IconData _getNotificationIcon(notification_models.NotificationType type) {
    switch (type) {
      case notification_models.NotificationType.follow:
        return Icons.person_add_alt_1_rounded;
      case notification_models.NotificationType.like:
        return Icons.favorite_rounded;
      case notification_models.NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case notification_models.NotificationType.bookmark:
        return Icons.bookmark_rounded;
      case notification_models.NotificationType.recipe:
        return Icons.restaurant_menu_rounded;
      case notification_models.NotificationType.recipeShare:
        return Icons.share_rounded;
      case notification_models.NotificationType.shoppingListShare:
        return Icons.shopping_basket_rounded;
      case notification_models.NotificationType.unknown:
        return Icons.notifications_rounded;
    }
  }

  /// Type icons are `brandInk`; a like is red, as on the feed card.
  Color _getNotificationColor(notification_models.NotificationType type, AppTokens t) {
    return type == notification_models.NotificationType.like ? const Color(0xFFE53935) : t.brandInk;
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                auth: widget.auth,
                apiClient: widget.apiClient,
                shoppingListController: widget.shoppingListController,
                username: notification.actorUsername!,
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
                shoppingListController: widget.shoppingListController,
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

  Widget _buildGuestState(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 20),
        title: Text(localizations?.notifications ?? "Notifications"),
      ),
      body: EmptyStateWidget(
        icon: Icons.notifications_none,
        title: localizations?.guestNotificationsTitle ?? "Stay in the loop",
        description: localizations?.guestNotificationsBody ??
            "Create an account to get notified when people like and comment on your recipes.",
        actionLabel: localizations?.createAccount ?? "Create account",
        actionIcon: Icons.person_add_outlined,
        onAction: () => requireAccount(context, widget.auth, AccountReason.notifications),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isLoggedIn) return _buildGuestState(context);
    return Scaffold(
      appBar: AppBar(
        // Bottom-nav tab root: 20px title, like the Profile tab.
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 20),
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
                  final localizations =
                      AppLocalizations.of(this.context);
                  ErrorUtils.showSuccess(
                    this.context,
                    localizations?.allNotificationsMarkedAsRead ??
                        "All notifications marked as read",
                  );
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
      return const SingleChildScrollView(child: ListRowSkeleton(leadingSize: 44, count: 8));
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
        title: _showUnreadOnly
            ? (AppLocalizations.of(context)?.noUnreadNotifications ?? "No unread notifications")
            : (AppLocalizations.of(context)?.noNotifications ?? "No notifications"),
        description: _showUnreadOnly
            ? (AppLocalizations.of(context)?.allCaughtUp ?? "You're all caught up!")
            : (AppLocalizations.of(context)?.notificationsEmptyDescription ?? "You'll see notifications here when someone interacts with your content"),
      );
    }

    return ListView.builder(
      controller: _scrollController,
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

  /// The actor's avatar (or, for notifications without one, a `soft` icon
  /// circle) with a small badge for the type. Unread rows sit on a light
  /// `soft` tint with a `brand` dot, like the nav's active dot.
  Widget _buildNotificationItem(notification_models.Notification notification) {
    final t = AppTokens.of(context);
    final icon = _getNotificationIcon(notification.type);
    final iconColor = _getNotificationColor(notification.type, t);
    final title = _getNotificationTitle(notification, context);
    final message = _getNotificationMessage(notification);
    final date = formatRelativeTime(context, notification.createdAt);
    final actor = notification.actorUsername;

    final Widget leading;
    if (actor != null && actor.isNotEmpty) {
      leading = SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(
              avatarUrl: notification.actorAvatarUrl,
              name: notification.actorDisplayName ?? actor,
              size: 44,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: t.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.line),
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
            ),
          ],
        ),
      );
    } else {
      leading = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: iconColor),
      );
    }

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
        color: t.danger,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: notification.isRead ? null : t.soft.withValues(alpha: 0.6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(fontSize: 13, color: t.ink2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(date, style: TextStyle(fontSize: 12, color: t.ink2)),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
