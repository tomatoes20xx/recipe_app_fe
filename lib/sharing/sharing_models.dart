import "../shopping/shopping_list_models.dart";

/// Represents a user who has access to shared content (recipe or shopping list)
class SharedWithUser {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime sharedAt;
  final String? shareType; // "read_only" or "collaborative" for shopping lists, null for recipes

  SharedWithUser({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.sharedAt,
    this.shareType,
  });

  factory SharedWithUser.fromJson(Map<String, dynamic> json) {
    // Handle avatar URL (check for null, empty, or "null" string)
    final avatarUrl = json["avatar_url"];
    final processedAvatarUrl = avatarUrl == null ||
                               avatarUrl == "null" ||
                               (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    return SharedWithUser(
      userId: json["user_id"].toString(),
      username: json["username"].toString(),
      displayName: json["display_name"]?.toString(),
      avatarUrl: processedAvatarUrl,
      sharedAt: DateTime.parse(json["shared_at"].toString()),
      shareType: json["share_type"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_id": userId,
      "username": username,
      "display_name": displayName,
      "avatar_url": avatarUrl,
      "shared_at": sharedAt.toIso8601String(),
      "share_type": shareType,
    };
  }
}

/// Represents a shopping list shared with you
class SharedShoppingList {
  final String ownerId;
  final String ownerUsername;
  final String? ownerDisplayName;
  final String? ownerAvatarUrl;
  final String shareType; // "read_only" or "collaborative"
  final DateTime sharedAt;
  final int itemCount;

  SharedShoppingList({
    required this.ownerId,
    required this.ownerUsername,
    this.ownerDisplayName,
    this.ownerAvatarUrl,
    required this.shareType,
    required this.sharedAt,
    required this.itemCount,
  });

  bool get isReadOnly => shareType == "read_only";
  bool get isCollaborative => shareType == "collaborative";

  factory SharedShoppingList.fromJson(Map<String, dynamic> json) {
    // Handle avatar URL (check for null, empty, or "null" string)
    final avatarUrl = json["owner_avatar_url"];
    final processedAvatarUrl = avatarUrl == null ||
                               avatarUrl == "null" ||
                               (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    return SharedShoppingList(
      ownerId: json["owner_id"].toString(),
      ownerUsername: json["owner_username"].toString(),
      ownerDisplayName: json["owner_display_name"]?.toString(),
      ownerAvatarUrl: processedAvatarUrl,
      shareType: json["share_type"].toString(),
      sharedAt: DateTime.parse(json["shared_at"].toString()),
      itemCount: json["item_count"] is int ? json["item_count"] as int : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "owner_id": ownerId,
      "owner_username": ownerUsername,
      "owner_display_name": ownerDisplayName,
      "owner_avatar_url": ownerAvatarUrl,
      "share_type": shareType,
      "shared_at": sharedAt.toIso8601String(),
      "item_count": itemCount,
    };
  }
}

/// Full shopping list data from another user
class SharedUserShoppingList {
  final String ownerId;
  final String ownerUsername;
  final String? ownerDisplayName;
  final String? ownerAvatarUrl;
  final String shareType; // "read_only" or "collaborative"
  final List<ShoppingListItem> items;

  SharedUserShoppingList({
    required this.ownerId,
    required this.ownerUsername,
    this.ownerDisplayName,
    this.ownerAvatarUrl,
    required this.shareType,
    required this.items,
  });

  bool get isReadOnly => shareType == "read_only";
  bool get isCollaborative => shareType == "collaborative";
  int get itemCount => items.length;
  int get checkedCount => items.where((item) => item.isChecked).length;
  int get uncheckedCount => items.where((item) => !item.isChecked).length;

  factory SharedUserShoppingList.fromJson(Map<String, dynamic> json) {
    // Handle avatar URL (check for null, empty, or "null" string)
    final avatarUrl = json["owner_avatar_url"];
    final processedAvatarUrl = avatarUrl == null ||
                               avatarUrl == "null" ||
                               (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    // Handle items - backend might return List or Map
    final itemsData = json["items"];
    final List<ShoppingListItem> items = [];

    if (itemsData is List) {
      for (final item in itemsData) {
        if (item is Map) {
          try {
            items.add(ShoppingListItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            // Skip invalid item
          }
        }
      }
    } else if (itemsData is Map) {
      // Items might be wrapped
      final nestedItems = itemsData["items"] ?? itemsData["data"];
      if (nestedItems is List) {
        for (final item in nestedItems) {
          if (item is Map) {
            try {
              items.add(ShoppingListItem.fromJson(Map<String, dynamic>.from(item)));
            } catch (e) {
              // Skip invalid item
            }
          }
        }
      }
    }

    return SharedUserShoppingList(
      ownerId: json["owner_id"].toString(),
      ownerUsername: json["owner_username"].toString(),
      ownerDisplayName: json["owner_display_name"]?.toString(),
      ownerAvatarUrl: processedAvatarUrl,
      shareType: json["share_type"].toString(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "owner_id": ownerId,
      "owner_username": ownerUsername,
      "owner_display_name": ownerDisplayName,
      "owner_avatar_url": ownerAvatarUrl,
      "share_type": shareType,
      "items": items.map((item) => item.toJson()).toList(),
    };
  }
}
