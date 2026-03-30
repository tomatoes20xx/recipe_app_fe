import 'package:flutter/foundation.dart';

class PaginatedResponse<T> {
  final List<T> items;
  final String? nextCursor;

  PaginatedResponse({required this.items, required this.nextCursor});
}

abstract class PaginatedListController<T> extends ChangeNotifier {
  final List<T> _items = [];
  List<T> get items => List.unmodifiable(_items);

  String? nextCursor;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  int limit = 20;

  Future<PaginatedResponse<T>> fetchPage(String? cursor);

  /// Loads the first page. Guards against concurrent calls.
  /// Override without calling super to remove the guard (e.g. FeedController).
  Future<void> loadInitial() async {
    if (isLoading) return;
    await doLoadInitial();
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    if (nextCursor == null) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final res = await fetchPage(nextCursor);
      _items.addAll(res.items);
      nextCursor = res.nextCursor;
    } catch (e) {
      onFetchError(e);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  void clear() {
    _items.clear();
    nextCursor = null;
    error = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // ── hooks & helpers for subclasses ──────────────────────────────────────

  /// Called when fetchPage throws. Override to customise error handling.
  @protected
  void onFetchError(Object e) {
    error = e.toString();
  }

  /// Actual load logic, without the isLoading guard.
  /// Call directly from subclasses that need to reload unconditionally.
  @protected
  Future<void> doLoadInitial() async {
    isLoading = true;
    error = null;
    _items.clear();
    nextCursor = null;
    notifyListeners();

    try {
      final res = await fetchPage(null);
      _items.addAll(res.items);
      nextCursor = res.nextCursor;
    } catch (e) {
      onFetchError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @protected
  void clearItems() {
    _items.clear();
  }

  @protected
  void appendItems(List<T> newItems) {
    _items.addAll(newItems);
  }

  @protected
  void removeItemWhere(bool Function(T) test) {
    _items.removeWhere(test);
    notifyListeners();
  }

  @protected
  int indexWhere(bool Function(T) test) => _items.indexWhere(test);

  @protected
  void updateItemAt(int index, T item) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = item;
  }
}
