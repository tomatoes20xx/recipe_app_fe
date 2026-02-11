double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

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

class RecipeCounts {
  final int likes;
  final int comments;
  final int bookmarks;

  RecipeCounts({required this.likes, required this.comments, required this.bookmarks});

  factory RecipeCounts.fromJson(Map<String, dynamic> json) {
    return RecipeCounts(
      likes: _asInt(json["likes"]),
      comments: _asInt(json["comments"]),
      bookmarks: _asInt(json["bookmarks"]),
    );
  }
}

class RecipeIngredient {
  final String id;
  final String displayName;
  final String normalizedName;
  final double? quantity;
  final String? unit;
  final int sortOrder;

  RecipeIngredient({
    required this.id,
    required this.displayName,
    required this.normalizedName,
    required this.quantity,
    required this.unit,
    required this.sortOrder,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json["id"].toString(),
      displayName: json["display_name"].toString(),
      normalizedName: json["normalized_name"].toString(),
      quantity: _asDouble(json["quantity"]),
      unit: json["unit"]?.toString(),
      sortOrder: _asInt(json["sort_order"]),
    );
  }
}

class RecipeStep {
  final String id;
  final String instruction;
  final int sortOrder;

  RecipeStep({required this.id, required this.instruction, required this.sortOrder});

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      id: json["id"].toString(),
      instruction: json["instruction"].toString(),
      sortOrder: _asInt(json["sort_order"]),
    );
  }
}

class RecipeDetail {
  final String id;
  final String title;
  final String? description;
  final String? cuisine;
  final List<String> tags;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty; // 'easy', 'medium', 'hard'
  final DateTime createdAt;
  final String authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  final RecipeCounts counts;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<RecipeImage> images;

  /// Whether the current viewer has liked this recipe (from API when loaded while logged in).
  final bool? viewerHasLiked;
  /// Whether the current viewer has bookmarked this recipe (from API when loaded while logged in).
  final bool? viewerHasBookmarked;

  RecipeDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.cuisine,
    required this.tags,
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
    required this.createdAt,
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.counts,
    required this.ingredients,
    required this.steps,
    required this.images,
    this.viewerHasLiked,
    this.viewerHasBookmarked,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    final tagsRaw = (json["tags"] as List?) ?? const [];
    final countsRaw = Map<String, dynamic>.from(json["counts"] as Map);

    final ingredientsRaw = (json["ingredients"] as List?) ?? const [];
    final stepsRaw = (json["steps"] as List?) ?? const [];
    final imagesRaw = (json["images"] as List?) ?? [];
    final images = imagesRaw
        .map((e) => RecipeImage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return RecipeDetail(
      id: json["id"].toString(),
      title: json["title"].toString(),
      description: json["description"]?.toString(),
      cuisine: json["cuisine"]?.toString(),
      tags: tagsRaw.map((e) => e.toString()).toList(),
      cookingTimeMin: json["cooking_time_min"] is int ? json["cooking_time_min"] as int : null,
      cookingTimeMax: json["cooking_time_max"] is int ? json["cooking_time_max"] as int : null,
      difficulty: json["difficulty"]?.toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      authorUsername: json["author_username"].toString(),
      authorDisplayName: json["author_display_name"]?.toString(),
      authorAvatarUrl: json["author_avatar_url"]?.toString(),
      counts: RecipeCounts.fromJson(countsRaw),
      ingredients: ingredientsRaw
          .map((e) => RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      steps: stepsRaw
          .map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      images: images,
      viewerHasLiked: json["viewer_has_liked"] is bool ? json["viewer_has_liked"] as bool : null,
      viewerHasBookmarked: json["viewer_has_bookmarked"] is bool ? json["viewer_has_bookmarked"] as bool : null,
    );
  }
}
