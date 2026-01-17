class Comment {
  final String id;
  final String content;
  final DateTime createdAt;
  final String authorUsername;
  final String? authorDisplayName;
  /// ID of the parent comment when this is a reply. Null for top-level comments.
  final String? parentId;
  final String? authorAvatarUrl;
  /// Whether the current viewer is the author of this comment.
  final bool viewerIsMe;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorUsername,
    this.authorDisplayName,
    this.parentId,
    this.authorAvatarUrl,
    this.viewerIsMe = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // API might return "body" instead of "content"
    final content = json["content"] ?? json["body"];
    return Comment(
      id: json["id"].toString(),
      content: content.toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      authorUsername: json["author_username"].toString(),
      authorDisplayName: json["author_display_name"]?.toString(),
      parentId: json["parent_id"]?.toString(),
      authorAvatarUrl: json["author_avatar_url"]?.toString(),
      viewerIsMe: json["viewer_is_me"] == true,
    );
  }
}
