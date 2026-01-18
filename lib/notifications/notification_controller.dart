import "package:flutter/foundation.dart";
import "notification_api.dart";
import "notification_models.dart" as notification_models;

class NotificationController extends ChangeNotifier {
  NotificationController({required this.notificationApi});

  final NotificationApi notificationApi;

  final List<notification_models.Notification> items = [];
  String? nextCursor;
  int unreadCount = 0;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  int limit = 20;

  /// Load initial notifications
  Future<void> loadInitial({bool unreadOnly = false}) async {
    isLoading = true;
    error = null;
    items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await notificationApi.getNotifications(
        limit: limit,
        cursor: null,
        unreadOnly: unreadOnly,
      );
      items.addAll(res.items);
      nextCursor = res.nextCursor;
      unreadCount = res.unreadCount;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore({bool unreadOnly = false}) async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await notificationApi.getNotifications(
        limit: limit,
        cursor: nextCursor,
        unreadOnly: unreadOnly,
      );
      items.addAll(res.items);
      nextCursor = res.nextCursor;
      unreadCount = res.unreadCount;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh notifications
  Future<void> refresh({bool unreadOnly = false}) async {
    await loadInitial(unreadOnly: unreadOnly);
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = items.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;

    final notification = items[index];
    if (notification.isRead) return;

    // Optimistic update
    items[index] = notification.copyWith(isRead: true);
    if (unreadCount > 0) {
      unreadCount--;
    }
    notifyListeners();

    try {
      await notificationApi.markAsRead(notificationId);
    } catch (e) {
      // Rollback on error
      items[index] = notification;
      if (unreadCount >= 0) {
        unreadCount++;
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    // Optimistic update
    final unreadItems = items.where((n) => !n.isRead).toList();
    for (var i = 0; i < items.length; i++) {
      if (!items[i].isRead) {
        items[i] = items[i].copyWith(isRead: true);
      }
    }
    final previousUnreadCount = unreadCount;
    unreadCount = 0;
    notifyListeners();

    try {
      await notificationApi.markAllAsRead();
    } catch (e) {
      // Rollback on error
      for (var notification in unreadItems) {
        final index = items.indexWhere((n) => n.id == notification.id);
        if (index >= 0) {
          items[index] = notification;
        }
      }
      unreadCount = previousUnreadCount;
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh unread count
  Future<void> refreshUnreadCount() async {
    try {
      unreadCount = await notificationApi.getUnreadCount();
      notifyListeners();
    } catch (e) {
      // Silently fail - don't update UI
    }
  }

  /// Clear all notifications
  void clear() {
    items.clear();
    nextCursor = null;
    unreadCount = 0;
    error = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }
}
