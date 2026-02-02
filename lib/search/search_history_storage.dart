import "dart:convert";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

class SearchHistoryStorage {
  static const _kSearchHistoryKey = "recent_searches";
  static const _maxHistoryItems = 3;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<String>> getRecentSearches() async {
    try {
      final data = await _storage.read(key: _kSearchHistoryKey);
      if (data == null || data.isEmpty) return [];
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final searches = await getRecentSearches();
    searches.remove(trimmed);
    searches.insert(0, trimmed);

    final limited = searches.take(_maxHistoryItems).toList();
    await _storage.write(key: _kSearchHistoryKey, value: jsonEncode(limited));
  }

  Future<void> removeSearch(String query) async {
    final searches = await getRecentSearches();
    searches.remove(query);
    await _storage.write(key: _kSearchHistoryKey, value: jsonEncode(searches));
  }

  Future<void> clearHistory() async {
    await _storage.delete(key: _kSearchHistoryKey);
  }
}
