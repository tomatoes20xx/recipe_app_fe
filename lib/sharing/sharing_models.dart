import "../shopping/shopping_list_models.dart";

/// Represents a user who has access to shared content (recipe or shopping list)
class SharedWithUser {
  final String? shareId; // ID of the share (for unsharing individual recipes)
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime sharedAt;
  final String? shareType; // "read_only" or "collaborative" for shopping lists, null for recipes

  SharedWithUser({
    this.shareId,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.sharedAt,
    this.shareType,
  });

  factory SharedWithUser.fromJson(Map<String, dynamic> json) {
    // Handle avatar URL (check for null, empty, or "null" string)
    final avatarUrl = json["avatar_url"] ?? json["avatarUrl"];
    final processedAvatarUrl = avatarUrl == null ||
                               avatarUrl == "null" ||
                               (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    // Handle sharedAt - may be missing in inline sharedWith arrays
    final sharedAtStr = json["shared_at"]?.toString() ?? json["sharedAt"]?.toString();
    final sharedAt = sharedAtStr != null && sharedAtStr.isNotEmpty
        ? DateTime.parse(sharedAtStr)
        : DateTime.now(); // Default to now if missing

    return SharedWithUser(
      shareId: json["share_id"]?.toString() ?? json["shareId"]?.toString(),
      userId: (json["user_id"] ?? json["userId"]).toString(),
      username: json["username"].toString(),
      displayName: (json["display_name"] ?? json["displayName"])?.toString(),
      avatarUrl: processedAvatarUrl,
      sharedAt: sharedAt,
      shareType: (json["share_type"] ?? json["shareType"])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "share_id": shareId,
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
    // Extract owner object (nested structure)
    final owner = json["owner"] as Map<String, dynamic>? ?? {};

    // Handle avatar URL
    final avatarUrl = owner["avatarUrl"] ?? owner["avatar_url"];
    final processedAvatarUrl = avatarUrl == null ||
                               avatarUrl == "null" ||
                               (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    // Handle date parsing safely
    final sharedAtStr = json["sharedAt"]?.toString();
    final sharedAt = sharedAtStr != null && sharedAtStr.isNotEmpty
        ? DateTime.parse(sharedAtStr)
        : DateTime.now();

    return SharedShoppingList(
      ownerId: (owner["userId"] ?? owner["user_id"] ?? "").toString(),
      ownerUsername: (owner["username"] ?? "").toString(),
      ownerDisplayName: (owner["displayName"] ?? owner["display_name"])?.toString(),
      ownerAvatarUrl: processedAvatarUrl,
      shareType: (json["shareType"] ?? json["share_type"] ?? "read_only").toString(),
      sharedAt: sharedAt,
      itemCount: json["totalItems"] ?? json["total_items"] ?? json["itemCount"] ?? json["item_count"] ?? 0,
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

/// Shared recipe shopping list (recipe-specific sharing)
/// Can represent either specific recipes or all recipes from a user
class SharedRecipeShoppingList {
  final String shareId;
  final String shareType; // "read_only" or "collaborative"
  final List<String> recipeIds; // Empty array means "all recipes"
  final String ownerId;
  final String ownerUsername;
  final String? ownerDisplayName;
  final String? ownerAvatarUrl;
  final DateTime sharedAt;
  final List<ShoppingListItem> items;

  SharedRecipeShoppingList({
    required this.shareId,
    required this.shareType,
    required this.recipeIds,
    required this.ownerId,
    required this.ownerUsername,
    this.ownerDisplayName,
    this.ownerAvatarUrl,
    required this.sharedAt,
    required this.items,
  });

  bool get isReadOnly => shareType == "read_only";
  bool get isCollaborative => shareType == "collaborative";
  bool get isAllRecipes => recipeIds.isEmpty;
  int get totalItems => items.length;
  int get checkedItems => items.where((item) => item.isChecked).length;

  factory SharedRecipeShoppingList.fromJson(Map<String, dynamic> json) {
    // Extract owner object
    final owner = json["owner"] as Map<String, dynamic>? ?? {};

    // Handle avatar URL
    final avatarUrl = owner["avatarUrl"] ?? owner["avatar_url"];
    final processedAvatarUrl = avatarUrl == null ||
                               avatarUrl == "null" ||
                               (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();

    // Handle recipeIds (could be array or null/empty)
    final recipeIdsData = json["recipeIds"] ?? json["recipe_ids"];
    final List<String> recipeIds = [];
    if (recipeIdsData is List) {
      recipeIds.addAll(recipeIdsData.map((id) => id.toString()));
    }

    // Handle items
    final itemsData = json["items"];
    final List<ShoppingListItem> items = [];
    if (itemsData is List) {
      for (final item in itemsData) {
        if (item is Map) {
          try {
            items.add(ShoppingListItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }
    }

    // Handle date parsing safely
    final sharedAtStr = json["sharedAt"]?.toString() ?? json["shared_at"]?.toString();
    final sharedAt = sharedAtStr != null && sharedAtStr.isNotEmpty
        ? DateTime.parse(sharedAtStr)
        : DateTime.now();

    final result = SharedRecipeShoppingList(
      shareId: (json["shareId"] ?? json["share_id"] ?? "").toString(),
      shareType: (json["shareType"] ?? json["share_type"] ?? "read_only").toString(),
      recipeIds: recipeIds,
      ownerId: (owner["userId"] ?? owner["user_id"] ?? "").toString(),
      ownerUsername: (owner["username"] ?? "").toString(),
      ownerDisplayName: (owner["displayName"] ?? owner["display_name"])?.toString(),
      ownerAvatarUrl: processedAvatarUrl,
      sharedAt: sharedAt,
      items: items,
    );

    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      "share_id": shareId,
      "share_type": shareType,
      "recipe_ids": recipeIds,
      "owner": {
        "user_id": ownerId,
        "username": ownerUsername,
        "display_name": ownerDisplayName,
        "avatar_url": ownerAvatarUrl,
      },
      "shared_at": sharedAt.toIso8601String(),
      "items": items.map((item) => item.toJson()).toList(),
    };
  }
}
