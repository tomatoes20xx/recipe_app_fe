import "../api/api_client.dart";
import "notification_models.dart";

class NotificationApi {
  NotificationApi(this.api);
  final ApiClient api;

  /// Get notifications with pagination
  Future<NotificationResponse> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
  }) async {
    final queryParams = <String, String>{
      "limit": limit.toString(),
      if (cursor != null) "cursor": cursor,
      // Only include unread_only parameter when it's true (to filter to unread only)
      // When false or null, omit it to get all notifications
      if (unreadOnly == true) "unread_only": "true",
    };

    final data = await api.get("/notifications", query: queryParams, auth: true);
    return NotificationResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await api.patch("/notifications/$notificationId/read", auth: true);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await api.post("/notifications/read-all", auth: true);
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final data = await api.get("/notifications/unread-count", auth: true);
      if (data is Map && data.containsKey("count")) {
        return data["count"] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    await api.delete("/notifications/$notificationId", auth: true);
  }

  /// Delete all notifications
  Future<Map<String, dynamic>> deleteAllNotifications() async {
    final data = await api.delete("/notifications", auth: true);
    return Map<String, dynamic>.from(data as Map);
  }
}
