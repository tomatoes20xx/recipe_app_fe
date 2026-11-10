import "dart:async";

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
      items.addAll(res.items.where((n) => !_pendingDeletes.containsKey(n.id)));
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
      items.addAll(res.items.where((n) => !_pendingDeletes.containsKey(n.id)));
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

  /// Silently fetch the first page and prepend any new items without
  /// clearing the list or showing a loading spinner.
  Future<void> silentRefresh({bool unreadOnly = false}) async {
    if (isLoading) return;
    try {
      final res = await notificationApi.getNotifications(
        limit: limit,
        cursor: null,
        unreadOnly: unreadOnly,
      );
      final existingIds = items.map((n) => n.id).toSet();
      final newItems = res.items.where((n) => !existingIds.contains(n.id)).toList();
      if (newItems.isNotEmpty) {
        items.insertAll(0, newItems);
      }
      unreadCount = res.unreadCount;
      _notify();
    } catch (_) {
      // Silently fail
    }
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

  /// Set unread count directly (called from FCM data message handler)
  void setUnreadCount(int count) {
    if (count != unreadCount) {
      unreadCount = count;
      _notify();
    }
  }

  /// Refresh unread count
  Future<void> refreshUnreadCount() async {
    try {
      final newCount = await notificationApi.getUnreadCount();
      if (newCount != unreadCount) {
        unreadCount = newCount;
        _notify();
      }
    } catch (e) {
      // Silently fail - don't update UI
    }
  }

  /// Deletes waiting for their undo window to pass, by notification id.
  final Map<String, Timer> _pendingDeletes = {};

  /// Removes [notificationId] from the list right away and deletes it on the
  /// server after [delay], unless the returned undo callback runs first.
  /// If the server delete fails, the notification comes back and [onError]
  /// gets the error.
  VoidCallback removeWithUndo(
    String notificationId, {
    Duration delay = const Duration(seconds: 4),
    void Function(Object error)? onError,
  }) {
    final index = items.indexWhere((n) => n.id == notificationId);
    if (index < 0) return () {};

    final removed = items[index];
    final wasUnread = !removed.isRead;
    items.removeAt(index);
    if (wasUnread && unreadCount > 0) unreadCount--;
    _notify();

    void restore() {
      if (_isDisposed) return;
      items.insert(index.clamp(0, items.length), removed);
      if (wasUnread) unreadCount++;
      _notify();
    }

    _pendingDeletes[notificationId] = Timer(delay, () async {
      _pendingDeletes.remove(notificationId);
      try {
        await notificationApi.deleteNotification(notificationId);
      } catch (e) {
        restore();
        onError?.call(e);
      }
    });

    return () {
      final timer = _pendingDeletes.remove(notificationId);
      if (timer == null) return; // already sent
      timer.cancel();
      restore();
    };
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
    // Send deletes still waiting for their undo window.
    for (final entry in _pendingDeletes.entries) {
      entry.value.cancel();
      notificationApi.deleteNotification(entry.key).catchError((_) {});
    }
    _pendingDeletes.clear();
    super.dispose();
  }

  void _notify() {
    if (_isDisposed) return;
    notifyListeners();
  }
}
