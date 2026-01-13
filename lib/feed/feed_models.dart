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
  final DateTime createdAt;
  final String authorUsername;
  final String? authorAvatarUrl;

  final int likes;
  final int comments;
  final int bookmarks;

  final bool viewerHasLiked;
  final bool viewerHasBookmarked;

  // present only when sort=top (optional)
  final int? likesWindow;

  final List<RecipeImage> images;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.likes,
    required this.comments,
    required this.bookmarks,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
    this.likesWindow,
    required this.images,
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
      description: json["description"] == null ? null : json["description"].toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      authorUsername: (json["author_username"] ?? "").toString(),
      authorAvatarUrl: json["author_avatar_url"]?.toString(),
      likes: (json["likes"] ?? 0) as int,
      comments: (json["comments"] ?? 0) as int,
      bookmarks: (json["bookmarks"] ?? 0) as int,
      viewerHasLiked: (json["viewer_has_liked"] ?? false) as bool,
      viewerHasBookmarked: (json["viewer_has_bookmarked"] ?? false) as bool,
      likesWindow: json["likes_window"] is int ? json["likes_window"] as int : null,
      images: images,
    );
  }

   FeedItem copyWith({
    int? likes,
    int? comments,
    int? bookmarks,
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
      createdAt: createdAt,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      bookmarks: bookmarks ?? this.bookmarks,
      viewerHasLiked: viewerHasLiked ?? this.viewerHasLiked,
      viewerHasBookmarked: viewerHasBookmarked ?? this.viewerHasBookmarked,
      likesWindow: likesWindow ?? this.likesWindow,
      images: images ?? this.images,
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
