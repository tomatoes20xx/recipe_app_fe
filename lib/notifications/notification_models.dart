/// Notification types
enum NotificationType {
  follow,      // Someone followed you
  like,        // Someone liked your recipe
  comment,     // Someone commented on your recipe
  bookmark,    // Someone bookmarked your recipe
  recipe,      // Someone you follow posted a recipe (optional)
  unknown,     // Unknown type (for future compatibility)
}

/// Notification model
class Notification {
  final String id;
  final NotificationType type;
  final String? title;
  final String? message;
  final String? actorUsername;      // User who triggered the notification
  final String? actorAvatarUrl;     // Avatar of the user who triggered it
  final String? recipeId;           // Related recipe (for likes, comments)
  final String? recipeTitle;        // Recipe title (for context)
  final DateTime createdAt;
  final bool isRead;

  Notification({
    required this.id,
    required this.type,
    this.title,
    this.message,
    this.actorUsername,
    this.actorAvatarUrl,
    this.recipeId,
    this.recipeTitle,
    required this.createdAt,
    required this.isRead,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    // Parse notification type
    NotificationType type;
    final typeStr = (json["type"] ?? "").toString().toLowerCase();
    switch (typeStr) {
      case "follow":
        type = NotificationType.follow;
        break;
      case "like":
        type = NotificationType.like;
        break;
      case "comment":
        type = NotificationType.comment;
        break;
      case "bookmark":
        type = NotificationType.bookmark;
        break;
      case "recipe":
        type = NotificationType.recipe;
        break;
      default:
        type = NotificationType.unknown;
    }

    // Handle avatar URL (check for null, empty, or "null" string)
    final avatarUrl = json["actor_avatar_url"];
    final actorAvatarUrl = avatarUrl == null || 
                          avatarUrl == "null" || 
                          (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    return Notification(
      id: json["id"].toString(),
      type: type,
      title: json["title"]?.toString(),
      message: json["message"]?.toString(),
      actorUsername: json["actor_username"]?.toString(),
      actorAvatarUrl: actorAvatarUrl,
      recipeId: json["recipe_id"]?.toString(),
      recipeTitle: json["recipe_title"]?.toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      isRead: json["is_read"] is bool ? json["is_read"] as bool : false,
    );
  }

  Notification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    String? actorUsername,
    String? actorAvatarUrl,
    String? recipeId,
    String? recipeTitle,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Notification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      actorUsername: actorUsername ?? this.actorUsername,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Notification response with pagination
class NotificationResponse {
  final List<Notification> items;
  final String? nextCursor;
  final int unreadCount;

  NotificationResponse({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json["items"] as List<dynamic>? ?? []);
    return NotificationResponse(
      items: rawItems
          .map((e) => Notification.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      nextCursor: json["nextCursor"]?.toString(),
      unreadCount: json["unread_count"] is int ? json["unread_count"] as int : 0,
    );
  }
}
