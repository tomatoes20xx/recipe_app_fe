import "package:flutter/foundation.dart";
import "notification_api.dart";
import "notification_models.dart" as notification_models;

class NotificationController extends ChangeNotifier {
  NotificationController({required this.notificationApi});

  final NotificationApi notificationApi;
  bool _isDisposed = false;

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
    _notify();

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
      _notify();
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore({bool unreadOnly = false}) async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    _notify();

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
      _notify();
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
    _notify();

    try {
      await notificationApi.markAsRead(notificationId);
    } catch (e) {
      // Rollback on error
      items[index] = notification;
      if (unreadCount >= 0) {
        unreadCount++;
      }
      _notify();
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
    _notify();

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
      _notify();
      rethrow;
    }
  }

  /// Refresh unread count
  Future<void> refreshUnreadCount() async {
    try {
      unreadCount = await notificationApi.getUnreadCount();
      _notify();
    } catch (e) {
      // Silently fail - don't update UI
    }
  }

  /// Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    final index = items.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;

    // Save for rollback
    final deletedNotification = items[index];
    final wasUnread = !deletedNotification.isRead;

    // Optimistic update
    items.removeAt(index);
    if (wasUnread && unreadCount > 0) {
      unreadCount--;
    }
    _notify();

    try {
      await notificationApi.deleteNotification(notificationId);
    } catch (e) {
      // Rollback on error
      items.insert(index, deletedNotification);
      if (wasUnread) {
        unreadCount++;
      }
      _notify();
      rethrow;
    }
  }

  /// Delete all notifications
  Future<int> deleteAllNotifications() async {
    // Save for rollback
    final previousItems = List<notification_models.Notification>.from(items);
    final previousUnreadCount = unreadCount;

    // Optimistic update
    items.clear();
    unreadCount = 0;
    nextCursor = null;
    _notify();

    try {
      final result = await notificationApi.deleteAllNotifications();
      final deleted = result["deleted"] as int? ?? 0;
      return deleted;
    } catch (e) {
      // Rollback on error
      items.addAll(previousItems);
      unreadCount = previousUnreadCount;
      _notify();
      rethrow;
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
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notify() {
    if (_isDisposed) return;
    notifyListeners();
  }
}
