class Comment {
  final String id;
  final String content;
  final DateTime createdAt;
  final String authorUsername;
  final String? authorDisplayName;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorUsername,
    this.authorDisplayName,
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
    );
  }
}
