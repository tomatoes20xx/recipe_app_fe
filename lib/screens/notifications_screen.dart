import "package:flutter/material.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../notifications/notification_api.dart";
import "../notifications/notification_controller.dart";
import "../notifications/notification_models.dart" as notification_models;
import "../recipes/recipe_detail_screen.dart";
import "../screens/profile_screen.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.notificationController,
  });

  final ApiClient apiClient;
  final AuthController auth;
  final NotificationController notificationController;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    widget.notificationController.addListener(_onControllerChanged);
    // Always refresh notifications when entering this screen
    if (widget.notificationController.items.isEmpty) {
      widget.notificationController.loadInitial();
    } else {
      // If already loaded, just refresh to get latest data
      widget.notificationController.refresh(unreadOnly: _showUnreadOnly);
    }
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
      case notification_models.NotificationType.unknown:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getNotificationTitle(notification_models.Notification notification) {
    if (notification.title != null && notification.title!.isNotEmpty) {
      return notification.title!;
    }

    final actor = notification.actorUsername ?? "Someone";
    switch (notification.type) {
      case notification_models.NotificationType.follow:
        return "$actor started following you";
      case notification_models.NotificationType.like:
        return "$actor liked your recipe";
      case notification_models.NotificationType.comment:
        return "$actor commented on your recipe";
      case notification_models.NotificationType.bookmark:
        return "$actor bookmarked your recipe";
      case notification_models.NotificationType.recipe:
        return "$actor posted a new recipe";
      case notification_models.NotificationType.unknown:
        return notification.message ?? "New notification";
    }
  }

  String? _getNotificationMessage(notification_models.Notification notification) {
    if (notification.message != null && notification.message!.isNotEmpty) {
      return notification.message;
    }

    switch (notification.type) {
      case notification_models.NotificationType.comment:
        return notification.recipeTitle != null
            ? "Commented on \"${notification.recipeTitle}\""
            : "Commented on your recipe";
      case notification_models.NotificationType.like:
        return notification.recipeTitle != null
            ? "Liked \"${notification.recipeTitle}\""
            : "Liked your recipe";
      case notification_models.NotificationType.bookmark:
        return notification.recipeTitle != null
            ? "Bookmarked \"${notification.recipeTitle}\""
            : "Bookmarked your recipe";
      case notification_models.NotificationType.recipe:
        return notification.recipeTitle != null
            ? "Posted \"${notification.recipeTitle}\""
            : "Posted a new recipe";
      default:
        return null;
    }
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
              ),
            ),
          );
        }
        break;

      case notification_models.NotificationType.recipe:
        if (notification.recipeId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(
                recipeId: notification.recipeId!,
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
            onSelected: (value) {
              setState(() {
                _showUnreadOnly = value == "unread";
              });
              widget.notificationController.loadInitial(unreadOnly: _showUnreadOnly);
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
    final title = _getNotificationTitle(notification);
    final message = _getNotificationMessage(notification);
    final date = _formatDate(notification.createdAt, context);

    return InkWell(
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
    );
  }
}
