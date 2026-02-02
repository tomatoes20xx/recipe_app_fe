import "../users/user_models.dart";

class SearchResult {
  final String id;
  final String title;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty;
  final DateTime createdAt;
  final String authorUsername;
  final String? authorAvatarUrl;

  SearchResult({
    required this.id,
    required this.title,
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
    required this.createdAt,
    required this.authorUsername,
    this.authorAvatarUrl,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final avatarUrl = json["author_avatar_url"];
    final authorAvatarUrl = avatarUrl == null || avatarUrl == "null" || (avatarUrl is String && avatarUrl.isEmpty)
        ? null
        : avatarUrl.toString();
    
    return SearchResult(
      id: json["id"].toString(),
      title: json["title"].toString(),
      cookingTimeMin: json["cooking_time_min"] is int ? json["cooking_time_min"] as int : null,
      cookingTimeMax: json["cooking_time_max"] is int ? json["cooking_time_max"] as int : null,
      difficulty: json["difficulty"]?.toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      authorUsername: json["author_username"].toString(),
      authorAvatarUrl: authorAvatarUrl,
    );
  }
}

class SearchResponse {
  final List<SearchResult> items;
  final String? nextCursor;

  SearchResponse({required this.items, required this.nextCursor});

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json["items"] as List<dynamic>? ?? []);
    return SearchResponse(
      items: rawItems.map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e))).toList(),
      nextCursor: json["nextCursor"]?.toString(),
    );
  }
}

class UnifiedSearchTypeResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  UnifiedSearchTypeResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}

class UnifiedSearchResponse {
  final UnifiedSearchTypeResult<SearchResult> recipes;
  final UnifiedSearchTypeResult<UserSearchResult> users;

  UnifiedSearchResponse({
    required this.recipes,
    required this.users,
  });

  factory UnifiedSearchResponse.fromJson(Map<String, dynamic> json) {
    final results = json["results"] as Map<String, dynamic>;

    final recipesData = results["recipes"] as Map<String, dynamic>? ?? {};
    final usersData = results["users"] as Map<String, dynamic>? ?? {};

    return UnifiedSearchResponse(
      recipes: UnifiedSearchTypeResult<SearchResult>(
        items: (recipesData["items"] as List<dynamic>? ?? [])
            .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nextCursor: recipesData["nextCursor"]?.toString(),
        hasMore: recipesData["hasMore"] as bool? ?? false,
      ),
      users: UnifiedSearchTypeResult<UserSearchResult>(
        items: (usersData["items"] as List<dynamic>? ?? [])
            .map((e) => UserSearchResult.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nextCursor: usersData["nextCursor"]?.toString(),
        hasMore: usersData["hasMore"] as bool? ?? false,
      ),
    );
  }
}
