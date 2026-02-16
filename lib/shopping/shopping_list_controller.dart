import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "shopping_list_api.dart";
import "shopping_list_models.dart";

class ShoppingListController extends ChangeNotifier {
  ShoppingListController({this.api}) {
    _loadItems();
  }

  final ShoppingListApi? api;
  static const String _storageKey = "shopping_list_items";
  static const String _lastSyncKey = "shopping_list_last_sync";

  List<ShoppingListItem> _items = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  List<ShoppingListItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isEmpty => _items.isEmpty;
  int get totalCount => _items.length;
  int get uncheckedCount => _items.where((i) => !i.isChecked).length;
  int get checkedCount => _items.where((i) => i.isChecked).length;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Get items grouped by recipe
  List<GroupedShoppingItems> get groupedItems {
    final Map<String, GroupedShoppingItems> groups = {};

    for (final item in _items) {
      if (!groups.containsKey(item.recipeId)) {
        groups[item.recipeId] = GroupedShoppingItems(
          recipeId: item.recipeId,
          recipeName: item.recipeName,
          recipeImage: item.recipeImage,
          items: [],
        );
      }
      groups[item.recipeId]!.items.add(item);
    }

    // Sort groups by most recent addition
    final sortedGroups = groups.values.toList()
      ..sort((a, b) {
        final aLatest = a.items.map((i) => i.addedAt).reduce((a, b) => a.isAfter(b) ? a : b);
        final bLatest = b.items.map((i) => i.addedAt).reduce((a, b) => a.isAfter(b) ? a : b);
        return bLatest.compareTo(aLatest);
      });

    return sortedGroups;
  }

  Future<void> _loadItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load last sync time
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      if (lastSyncString != null) {
        _lastSyncTime = DateTime.parse(lastSyncString);
      }

      // Try to load from API first (source of truth)
      if (api != null) {
        try {
          final serverItems = await api!.getItems();
          _items = serverItems;
          _lastSyncTime = DateTime.now();
          await _saveToCache();
          await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
        } on SocketException {
          // No internet - load from cache
          await _loadFromCache();
        } catch (e) {
          // API error - fallback to cache
          await _loadFromCache();
        }
      } else {
        // No API - load from cache (backward compatibility)
        await _loadFromCache();
      }
    } catch (e) {
      // Error loading shopping list
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load items from local cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _items = jsonList.map((json) => ShoppingListItem.fromJson(json)).toList();
      }
    } catch (e) {
      // Error loading from cache
    }
  }

  /// Save items to local cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      // Error saving to cache
    }
  }

  /// Sync items with server
  Future<void> syncWithServer() async {
    if (api == null || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final serverItems = await api!.getItems();
      _items = serverItems;
      _lastSyncTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
      await _saveToCache();
    } catch (e) {
      // Error syncing with server
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Add multiple items to shopping list
  Future<void> addItems(List<ShoppingListItem> newItems) async {
    if (newItems.isEmpty) return;

    // Optimistic update - add to local list immediately
    final existingKeys = _items.map((i) => "${i.recipeId}_${i.ingredientId}").toSet();
    final itemsToAdd = newItems.where((item) {
      final key = "${item.recipeId}_${item.ingredientId}";
      return !existingKeys.contains(key);
    }).toList();

    if (itemsToAdd.isEmpty) return;

    _items.addAll(itemsToAdd);
    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        final addedItems = await api!.addItems(itemsToAdd);

        // Replace local items with server versions (to get server-generated IDs)
        for (final serverItem in addedItems) {
          final localIndex = _items.indexWhere((i) =>
            i.recipeId == serverItem.recipeId && i.ingredientId == serverItem.ingredientId);
          if (localIndex != -1) {
            _items[localIndex] = serverItem;
          }
        }

        await _saveToCache();
        notifyListeners();
      } on SocketException {
        // Offline - items are already added locally, will sync later
      } catch (e) {
        // Items remain in local cache
      }
    }
  }

  /// Toggle item checked state
  Future<void> toggleItem(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final newCheckedState = !_items[index].isChecked;

    // Optimistic update
    _items[index] = _items[index].copyWith(isChecked: newCheckedState);
    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        final updatedItem = await api!.updateItem(itemId, isChecked: newCheckedState);
        if (updatedItem != null) {
          // Update with server version
          final idx = _items.indexWhere((i) => i.id == itemId);
          if (idx != -1) {
            _items[idx] = updatedItem;
            await _saveToCache();
          }
        }
      } on SocketException {
        // Offline - change is saved locally
      } catch (e) {
        // Error syncing toggle to server
      }
    }
  }

  /// Toggle all items in a recipe group
  Future<void> toggleRecipeGroup(String recipeId, bool checked) async {
    final itemsToToggle = <String>[];

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].recipeId == recipeId && _items[i].isChecked != checked) {
        itemsToToggle.add(_items[i].id);
        _items[i] = _items[i].copyWith(isChecked: checked);
      }
    }

    if (itemsToToggle.isEmpty) return;

    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        for (final itemId in itemsToToggle) {
          await api!.updateItem(itemId, isChecked: checked);
        }
      } on SocketException {
        // Offline - recipe group toggled locally
      } catch (e) {
        // Error syncing recipe group toggle
      }
    }
  }

  /// Remove a single item
  Future<void> removeItem(String itemId) async {
    final initialLength = _items.length;
    _items.removeWhere((i) => i.id == itemId);

    if (_items.length == initialLength) return;

    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        await api!.deleteItem(itemId);
      } on SocketException {
        // Offline - item removed locally
      } catch (e) {
        // Error syncing item deletion
      }
    }
  }

  /// Remove all items from a recipe
  Future<void> removeRecipeItems(String recipeId) async {
    final itemsToRemove = _items.where((i) => i.recipeId == recipeId).map((i) => i.id).toList();
    if (itemsToRemove.isEmpty) return;

    _items.removeWhere((i) => i.recipeId == recipeId);
    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        await api!.deleteItems(itemsToRemove);
      } on SocketException {
        // Offline - recipe items removed locally
      } catch (e) {
        // Error syncing recipe items deletion
      }
    }
  }

  /// Clear all checked items
  Future<void> clearCheckedItems() async {
    final checkedItemIds = _items.where((i) => i.isChecked).map((i) => i.id).toList();
    if (checkedItemIds.isEmpty) return;

    _items.removeWhere((i) => i.isChecked);
    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        await api!.deleteItems(checkedItemIds);
      } on SocketException {
        // Offline - checked items cleared locally
      } catch (e) {
        // Error syncing checked items deletion
      }
    }
  }

  /// Clear all items
  Future<void> clearAll() async {
    if (_items.isEmpty) return;

    final allItemIds = _items.map((i) => i.id).toList();
    _items.clear();
    notifyListeners();
    await _saveToCache();

    // Sync with server
    if (api != null) {
      try {
        await api!.deleteItems(allItemIds);
      } on SocketException {
        // Offline - all items cleared locally
      } catch (e) {
        // Error syncing clear all
      }
    }
  }
}
