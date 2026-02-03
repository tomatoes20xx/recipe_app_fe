// Analytics statistics models

class AnalyticsStats {
  final OverallStats overall;
  final List<EventByType> byType;
  final List<TopRecipe> topRecipes;
  final List<DailyEvent> dailyEvents;

  AnalyticsStats({
    required this.overall,
    required this.byType,
    required this.topRecipes,
    required this.dailyEvents,
  });

  factory AnalyticsStats.fromJson(Map<String, dynamic> json) {
    return AnalyticsStats(
      overall: OverallStats.fromJson(Map<String, dynamic>.from(json["overall"] as Map)),
      byType: (json["by_type"] as List<dynamic>? ?? [])
          .map((e) => EventByType.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      topRecipes: (json["top_recipes"] as List<dynamic>? ?? [])
          .map((e) => TopRecipe.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      dailyEvents: (json["daily_events"] as List<dynamic>? ?? [])
          .map((e) => DailyEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class OverallStats {
  final int totalEvents;
  final int uniqueUsers;
  final int uniqueRecipes;
  final int eventsLast24h;
  final int eventsLast7d;
  final int eventsLast30d;

  OverallStats({
    required this.totalEvents,
    required this.uniqueUsers,
    required this.uniqueRecipes,
    required this.eventsLast24h,
    required this.eventsLast7d,
    required this.eventsLast30d,
  });

  factory OverallStats.fromJson(Map<String, dynamic> json) {
    return OverallStats(
      totalEvents: (json["total_events"] ?? 0) as int,
      uniqueUsers: (json["unique_users"] ?? 0) as int,
      uniqueRecipes: (json["unique_recipes"] ?? 0) as int,
      eventsLast24h: (json["events_last_24h"] ?? 0) as int,
      eventsLast7d: (json["events_last_7d"] ?? 0) as int,
      eventsLast30d: (json["events_last_30d"] ?? 0) as int,
    );
  }
}

class EventByType {
  final String eventType;
  final int total;
  final int last24h;
  final int last7d;

  EventByType({
    required this.eventType,
    required this.total,
    required this.last24h,
    required this.last7d,
  });

  factory EventByType.fromJson(Map<String, dynamic> json) {
    return EventByType(
      eventType: (json["event_type"] ?? "").toString(),
      total: (json["total"] ?? 0) as int,
      last24h: (json["last_24h"] ?? 0) as int,
      last7d: (json["last_7d"] ?? 0) as int,
    );
  }
}

class TopRecipe {
  final String recipeId;
  final String recipeTitle;
  final String authorUsername;
  final int totalEvents;
  final int views;
  final int likes;
  final int bookmarks;
  final int comments;

  TopRecipe({
    required this.recipeId,
    required this.recipeTitle,
    required this.authorUsername,
    required this.totalEvents,
    required this.views,
    required this.likes,
    required this.bookmarks,
    required this.comments,
  });

  factory TopRecipe.fromJson(Map<String, dynamic> json) {
    return TopRecipe(
      recipeId: (json["recipe_id"] ?? "").toString(),
      recipeTitle: (json["recipe_title"] ?? "").toString(),
      authorUsername: (json["author_username"] ?? "").toString(),
      totalEvents: (json["total_events"] ?? 0) as int,
      views: (json["views"] ?? 0) as int,
      likes: (json["likes"] ?? 0) as int,
      bookmarks: (json["bookmarks"] ?? 0) as int,
      comments: (json["comments"] ?? 0) as int,
    );
  }
}

class DailyEvent {
  final DateTime date;
  final int total;
  final int views;
  final int likes;
  final int bookmarks;
  final int comments;

  DailyEvent({
    required this.date,
    required this.total,
    required this.views,
    required this.likes,
    required this.bookmarks,
    required this.comments,
  });

  factory DailyEvent.fromJson(Map<String, dynamic> json) {
    return DailyEvent(
      date: DateTime.parse(json["date"].toString()),
      total: (json["total"] ?? 0) as int,
      views: (json["views"] ?? 0) as int,
      likes: (json["likes"] ?? 0) as int,
      bookmarks: (json["bookmarks"] ?? 0) as int,
      comments: (json["comments"] ?? 0) as int,
    );
  }
}

class AnalyticsEvent {
  final String id;
  final String eventType;
  final DateTime createdAt;
  final String? userId;
  final String? userUsername;
  final String? recipeId;
  final String? recipeTitle;
  final Map<String, dynamic>? metadata;

  AnalyticsEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.userId,
    this.userUsername,
    this.recipeId,
    this.recipeTitle,
    this.metadata,
  });

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedMetadata;
    final rawMetadata = json["metadata"];
    if (rawMetadata != null) {
      if (rawMetadata is Map) {
        parsedMetadata = Map<String, dynamic>.from(rawMetadata);
      }
      // If metadata is a string or other type, ignore it
    }

    return AnalyticsEvent(
      id: (json["id"] ?? "").toString(),
      eventType: (json["event_type"] ?? "").toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      userId: json["user_id"]?.toString(),
      userUsername: json["user_username"]?.toString(),
      recipeId: json["recipe_id"]?.toString(),
      recipeTitle: json["recipe_title"]?.toString(),
      metadata: parsedMetadata,
    );
  }
}

class AnalyticsEventsResponse {
  final List<AnalyticsEvent> items;
  final String? nextCursor;

  AnalyticsEventsResponse({
    required this.items,
    this.nextCursor,
  });

  factory AnalyticsEventsResponse.fromJson(Map<String, dynamic> json) {
    return AnalyticsEventsResponse(
      items: (json["items"] as List<dynamic>? ?? [])
          .map((e) => AnalyticsEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nextCursor: json["nextCursor"]?.toString(),
    );
  }
}
