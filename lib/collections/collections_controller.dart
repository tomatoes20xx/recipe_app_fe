import 'package:flutter/foundation.dart';

import 'collection_api.dart';
import 'collection_models.dart';

class CollectionsController extends ChangeNotifier {
  CollectionsController({required this.collectionApi});

  final CollectionApi collectionApi;

  List<Collection> items = [];
  bool isLoading = false;
  String? error;

  String? searchQuery;
  String sort = 'newest';

  /// Updates search/sort params and reloads.
  Future<void> setParams({String? query, String? newSort}) async {
    searchQuery = (query?.isEmpty ?? true) ? null : query;
    if (newSort != null) sort = newSort;
    await loadCollections();
  }

  Future<void> loadCollections() async {
    if (isLoading) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await collectionApi.getCollections(
        q: searchQuery,
        sort: sort,
      );
      items = res.items;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Collection> createCollection(String name) async {
    final collection = await collectionApi.createCollection(name);
    items.insert(0, collection);
    notifyListeners();
    return collection;
  }

  Future<void> renameCollection(String id, String name) async {
    final updated = await collectionApi.renameCollection(id, name);
    final index = items.indexWhere((c) => c.id == id);
    if (index >= 0) {
      items[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteCollection(String id) async {
    await collectionApi.deleteCollection(id);
    items.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
