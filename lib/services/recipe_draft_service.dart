import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class RecipeDraftService {
  static const String _draftKey = 'recipe_creation_draft';

  Future<void> saveDraft({
    required String title,
    required String description,
    required String cuisine,
    required List<String> tags,
    required String cookingTimeMin,
    required String cookingTimeMax,
    String? difficulty,
    required List<Map<String, String>> ingredients,
    required List<String> steps,
    required List<String> imagePaths,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = <String, dynamic>{
      'title': title,
      'description': description,
      'cuisine': cuisine,
      'tags': tags,
      'cookingTimeMin': cookingTimeMin,
      'cookingTimeMax': cookingTimeMax,
      'difficulty': difficulty ?? '',
      'ingredients': ingredients,
      'steps': steps,
      'imagePaths': imagePaths.where((p) => File(p).existsSync()).toList(),
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_draftKey);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_draftKey);
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
