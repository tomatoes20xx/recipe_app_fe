import "../feed/feed_models.dart";

class UserSearchResult {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool viewerIsFollowing;
  final bool viewerIsMe; // true if this is the current user

  UserSearchResult({
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.viewerIsFollowing,
    required this.viewerIsMe,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      username: json["username"].toString(),
      displayName: json["display_name"]?.toString(),
      avatarUrl: json["avatar_url"]?.toString(),
      viewerIsFollowing: json["viewer_is_following"] as bool? ?? false,
      viewerIsMe: json["viewer_is_me"] as bool? ?? false,
    );
  }

  UserSearchResult copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    bool? viewerIsFollowing,
    bool? viewerIsMe,
  }) {
    return UserSearchResult(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      viewerIsFollowing: viewerIsFollowing ?? this.viewerIsFollowing,
      viewerIsMe: viewerIsMe ?? this.viewerIsMe,
    );
  }
}

class UserSearchResponse {
  final List<UserSearchResult> items;
  final String? nextCursor;

  UserSearchResponse({
    required this.items,
    this.nextCursor,
  });

  factory UserSearchResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json["items"] as List?) ?? [];
    final items = itemsRaw
        .map((e) => UserSearchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return UserSearchResponse(
      items: items,
      nextCursor: json["nextCursor"]?.toString(),
    );
  }
}

class UserRecipesResponse {
  final List<FeedItem> items;
  final String? nextCursor;

  UserRecipesResponse({
    required this.items,
    this.nextCursor,
  });

  factory UserRecipesResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json["items"] as List?) ?? [];
    final items = itemsRaw
        .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return UserRecipesResponse(
      items: items,
      nextCursor: json["nextCursor"]?.toString(),
    );
  }
}

class UserProfile {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int recipesCount;
  final bool viewerIsFollowing;
  final bool isViewer; // true if this is the current user's profile
  final UserPrivacySettings? privacy; // Only visible to the user themselves

  UserProfile({
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.recipesCount,
    required this.viewerIsFollowing,
    required this.isViewer,
    this.privacy,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final counts = json["counts"] as Map<String, dynamic>? ?? {};
    final viewer = json["viewer"] as Map<String, dynamic>?;
    final privacyRaw = json["privacy"] as Map<String, dynamic>?;

    return UserProfile(
      username: json["username"].toString(),
      displayName: json["display_name"]?.toString(),
      avatarUrl: json["avatar_url"]?.toString(),
      bio: json["bio"]?.toString(),
      followersCount: (counts["followers"] ?? 0) as int,
      followingCount: (counts["following"] ?? 0) as int,
      recipesCount: (counts["recipes"] ?? 0) as int,
      viewerIsFollowing: viewer?["is_following"] as bool? ?? false,
      isViewer: viewer?["is_me"] as bool? ?? false,
      privacy: privacyRaw != null ? UserPrivacySettings.fromJson(privacyRaw) : null,
    );
  }

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? recipesCount,
    bool? viewerIsFollowing,
    bool? isViewer,
    UserPrivacySettings? privacy,
  }) {
    return UserProfile(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      recipesCount: recipesCount ?? this.recipesCount,
      viewerIsFollowing: viewerIsFollowing ?? this.viewerIsFollowing,
      isViewer: isViewer ?? this.isViewer,
      privacy: privacy ?? this.privacy,
    );
  }
}

class UserPrivacySettings {
  final bool followersPrivate;
  final bool followingPrivate;

  UserPrivacySettings({
    required this.followersPrivate,
    required this.followingPrivate,
  });

  factory UserPrivacySettings.fromJson(Map<String, dynamic> json) {
    return UserPrivacySettings(
      followersPrivate: (json["followers_private"] ?? false) as bool,
      followingPrivate: (json["following_private"] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "followers_private": followersPrivate,
      "following_private": followingPrivate,
    };
  }

  UserPrivacySettings copyWith({
    bool? followersPrivate,
    bool? followingPrivate,
  }) {
    return UserPrivacySettings(
      followersPrivate: followersPrivate ?? this.followersPrivate,
      followingPrivate: followingPrivate ?? this.followingPrivate,
    );
  }
}
