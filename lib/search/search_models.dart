class SearchResult {
  final String id;
  final String title;
  final DateTime createdAt;
  final String authorUsername;
  final String? authorAvatarUrl;

  SearchResult({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.authorUsername,
    this.authorAvatarUrl,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json["id"].toString(),
      title: json["title"].toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      authorUsername: json["author_username"].toString(),
      authorAvatarUrl: json["author_avatar_url"]?.toString(),
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
