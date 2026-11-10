import "dart:convert";
import "dart:developer";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:uuid/uuid.dart";

import "shopping_list_api.dart";
import "shopping_list_models.dart";

class ShoppingListController extends ChangeNotifier {
  ShoppingListController({this.api}) {
    _loadItems();
  }

  final ShoppingListApi? api;
  static const _uuid = Uuid();
  static const _storage = FlutterSecureStorage();
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

  /// Items added from recipes (the Recipes tab).
  List<ShoppingListItem> get recipeItems => _items.where((i) => !i.isManual).toList();

  /// Items typed in on the Manual tab, newest first.
  List<ShoppingListItem> get manualItems => _items.where((i) => i.isManual).toList();
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Get items grouped by recipe
  List<GroupedShoppingItems> get groupedItems {
    final Map<String, GroupedShoppingItems> groups = {};
    final Map<String, DateTime> latestDates = {};

    for (final item in _items) {
      final recipeId = item.recipeId;
      if (recipeId == null) continue; // manual items live on their own tab
      if (!groups.containsKey(recipeId)) {
        groups[recipeId] = GroupedShoppingItems(
          recipeId: recipeId,
          recipeName: item.recipeName ?? "",
          recipeImage: item.recipeImage,
          items: [],
        );
        latestDates[recipeId] = item.addedAt;
      } else if (item.addedAt.isAfter(latestDates[recipeId]!)) {
        latestDates[recipeId] = item.addedAt;
      }
      groups[recipeId]!.items.add(item);
    }

    return groups.values.toList()
      ..sort((a, b) => latestDates[b.recipeId]!.compareTo(latestDates[a.recipeId]!));
  }

  Future<void> _loadItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load last sync time
      final lastSyncString = await _storage.read(key: _lastSyncKey);
      if (lastSyncString != null) {
        _lastSyncTime = DateTime.parse(lastSyncString);
      }

      // Try to load from API first (source of truth). Guests have no server
      // list, so skip the call instead of collecting a 401.
      final hasSession = (await api?.api.tokenStorage.readToken())?.isNotEmpty == true;
      if (api != null && hasSession) {
        try {
          final serverItems = await api!.getItems();
          _items = serverItems;
          _lastSyncTime = DateTime.now();
          await _saveToCache();
          await _storage.write(key: _lastSyncKey, value: _lastSyncTime!.toIso8601String());
        } on SocketException {
          // No internet - load from cache
          await _loadFromCache();
        } catch (e) {
          // API error - fallback to cache
          await _loadFromCache();
        }
      } else {
        // No API or no session - load from cache (backward compatibility)
        await _loadFromCache();
      }
    } catch (e) {
      log("Error loading shopping list: $e", name: "ShoppingListController");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load items from local cache
  Future<void> _loadFromCache() async {
    try {
      final String? jsonString = await _storage.read(key: _storageKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _items = jsonList.map((json) => ShoppingListItem.fromJson(json)).toList();
      }
    } catch (e) {
      log("Error loading shopping list from cache: $e", name: "ShoppingListController");
    }
  }

  /// Save items to local cache
  Future<void> _saveToCache() async {
    try {
      final jsonList = _items.map((item) => item.toJson()).toList();
      await _storage.write(key: _storageKey, value: json.encode(jsonList));
    } catch (e) {
      log("Error saving shopping list to cache: $e", name: "ShoppingListController");
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

      await _storage.write(key: _lastSyncKey, value: _lastSyncTime!.toIso8601String());
      await _saveToCache();
    } catch (e) {
      log("Error syncing shopping list with server: $e", name: "ShoppingListController");
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
        log("Error syncing added items to server: $e", name: "ShoppingListController");
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
        log("Error syncing item toggle to server: $e", name: "ShoppingListController");
      }
    }
  }

  /// Add a manual item (not from a recipe) to the Manual tab.
  Future<void> addManualItem({required String name, double? quantity, String? unit}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final id = _uuid.v4();
    await addItems([
      ShoppingListItem(
        id: id,
        ingredientId: id,
        name: trimmed,
        quantity: quantity,
        unit: (unit == null || unit.trim().isEmpty) ? null : unit.trim(),
        addedAt: DateTime.now(),
      ),
    ]);
  }

  /// Check or uncheck several items at once (a merged "By ingredient" row).
  Future<void> toggleItems(List<String> ids, bool checked) async {
    final changed = <String>[];
    for (int i = 0; i < _items.length; i++) {
      if (ids.contains(_items[i].id) && _items[i].isChecked != checked) {
        changed.add(_items[i].id);
        _items[i] = _items[i].copyWith(isChecked: checked);
      }
    }
    if (changed.isEmpty) return;

    notifyListeners();
    await _saveToCache();

    if (api != null) {
      try {
        await Future.wait([
          for (final itemId in changed) api!.updateItem(itemId, isChecked: checked),
        ]);
      } on SocketException {
        // Offline - toggled locally
      } catch (e) {
        log("Error syncing items toggle to server: $e", name: "ShoppingListController");
      }
    }
  }

  /// Remove several items at once (a merged row).
  Future<void> removeItems(List<String> ids) => _removeWhere((i) => ids.contains(i.id));

  Future<void> _removeWhere(bool Function(ShoppingListItem) test) async {
    final ids = _items.where(test).map((i) => i.id).toList();
    if (ids.isEmpty) return;

    _items.removeWhere(test);
    notifyListeners();
    await _saveToCache();

    if (api != null) {
      try {
        await api!.deleteItems(ids);
      } on SocketException {
        // Offline - removed locally
      } catch (e) {
        log("Error syncing items deletion to server: $e", name: "ShoppingListController");
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
        await Future.wait([
          for (final itemId in itemsToToggle)
            api!.updateItem(itemId, isChecked: checked),
        ]);
      } on SocketException {
        // Offline - recipe group toggled locally
      } catch (e) {
        log("Error syncing recipe group toggle to server: $e", name: "ShoppingListController");
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
        log("Error syncing item deletion to server: $e", name: "ShoppingListController");
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
        log("Error syncing recipe items deletion to server: $e", name: "ShoppingListController");
      }
    }
  }

  /// Clear checked items; with [manual] set, only that tab's items.
  Future<void> clearCheckedItems({bool? manual}) =>
      _removeWhere((i) => i.isChecked && (manual == null || i.isManual == manual));

  /// Forget the local copy without touching the server (used on sign-out,
  /// so the next person on this device doesn't see the list).
  Future<void> clearLocal() async {
    _items.clear();
    _lastSyncTime = null;
    notifyListeners();
    try {
      await _storage.delete(key: _storageKey);
      await _storage.delete(key: _lastSyncKey);
    } catch (e) {
      log("Error clearing shopping list cache: $e", name: "ShoppingListController");
    }
  }

  /// Clear all items; with [manual] set, only that tab's items.
  Future<void> clearAll({bool? manual}) => _removeWhere((i) => manual == null || i.isManual == manual);
}
