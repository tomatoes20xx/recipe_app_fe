import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecipeDraftService {
  static const String _draftKey = 'recipe_creation_draft';
  static const _storage = FlutterSecureStorage();

  Future<void> saveDraft({
    required String title,
    required String description,
    required String cuisine,
    required List<String> tags,
    required String cookingTimeMin,
    required String cookingTimeMax,
    String servingSize = '',
    String? difficulty,
    required List<Map<String, String>> ingredients,
    required List<String> steps,
    required List<String> imagePaths,
  }) async {
    final draft = <String, dynamic>{
      'title': title,
      'description': description,
      'cuisine': cuisine,
      'tags': tags,
      'cookingTimeMin': cookingTimeMin,
      'cookingTimeMax': cookingTimeMax,
      'servingSize': servingSize,
      'difficulty': difficulty ?? '',
      'ingredients': ingredients,
      'steps': steps,
      'imagePaths': imagePaths.where((p) => File(p).existsSync()).toList(),
    };
    await _storage.write(key: _draftKey, value: jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final json = await _storage.read(key: _draftKey);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasDraft() async {
    return await _storage.containsKey(key: _draftKey);
  }

  Future<void> clearDraft() async {
    await _storage.delete(key: _draftKey);
  }
}
