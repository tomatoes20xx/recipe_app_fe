class RecipeImage {
  final String id;
  final String url;
  final int width;
  final int height;
  final int sortOrder;

  RecipeImage({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
    required this.sortOrder,
  });

  factory RecipeImage.fromJson(Map<String, dynamic> json) {
    return RecipeImage(
      id: json["id"].toString(),
      url: json["url"].toString(),
      width: (json["width"] ?? 0) as int,
      height: (json["height"] ?? 0) as int,
      sortOrder: (json["sort_order"] ?? 0) as int,
    );
  }
}

class FeedItem {
  final String id;
  final String title;
  final String? description;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty; // 'easy', 'medium', 'hard'
  final DateTime createdAt;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  final int likes;
  final int comments;
  final int bookmarks;
  final int shares;

  final bool viewerHasLiked;
  final bool viewerHasBookmarked;

  // present only when sort=top (optional)
  final int? likesWindow;

  final List<RecipeImage> images;

  // present only when this item comes from shared-with-me feed
  final String? shareId;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
    required this.createdAt,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.likes,
    required this.comments,
    required this.bookmarks,
    required this.shares,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
    this.likesWindow,
    required this.images,
    this.shareId,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final imagesRaw = (json["images"] as List?) ?? [];
    final images = imagesRaw
        .map((e) => RecipeImage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return FeedItem(
      id: json["id"].toString(),
      title: (json["title"] ?? "").toString(),
      description: json["description"]?.toString(),
      cookingTimeMin: json["cooking_time_min"] is int ? json["cooking_time_min"] as int : null,
      cookingTimeMax: json["cooking_time_max"] is int ? json["cooking_time_max"] as int : null,
      difficulty: json["difficulty"]?.toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      authorUsername: (json["author_username"] ?? "").toString(),
      authorDisplayName: json["author_display_name"]?.toString(),
      authorAvatarUrl: json["author_avatar_url"]?.toString(),
      likes: (json["likes"] ?? 0) as int,
      comments: (json["comments"] ?? 0) as int,
      bookmarks: (json["bookmarks"] ?? 0) as int,
      shares: (json["shares"] ?? 0) as int,
      viewerHasLiked: (json["viewer_has_liked"] ?? false) as bool,
      viewerHasBookmarked: (json["viewer_has_bookmarked"] ?? false) as bool,
      likesWindow: json["likes_window"] is int ? json["likes_window"] as int : null,
      images: images,
      shareId: json["share_id"]?.toString(),
    );
  }

   FeedItem copyWith({
    int? likes,
    int? comments,
    int? bookmarks,
    int? shares,
    bool? viewerHasLiked,
    bool? viewerHasBookmarked,
    int? likesWindow,
    List<RecipeImage>? images,
    String? description,
  }) {
    return FeedItem(
      id: id,
      title: title,
      description: description ?? this.description,
      cookingTimeMin: cookingTimeMin,
      cookingTimeMax: cookingTimeMax,
      difficulty: difficulty,
      createdAt: createdAt,
      authorUsername: authorUsername,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      bookmarks: bookmarks ?? this.bookmarks,
      shares: shares ?? this.shares,
      viewerHasLiked: viewerHasLiked ?? this.viewerHasLiked,
      viewerHasBookmarked: viewerHasBookmarked ?? this.viewerHasBookmarked,
      likesWindow: likesWindow ?? this.likesWindow,
      images: images ?? this.images,
      shareId: shareId,
    );
  }
}

class FeedResponse {
  final List<FeedItem> items;
  final String? nextCursor;

  FeedResponse({required this.items, required this.nextCursor});

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json["items"] as List<dynamic>? ?? []);
    return FeedResponse(
      items: rawItems.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      nextCursor: json["nextCursor"]?.toString(),
    );
  }
}
