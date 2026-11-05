import "package:flutter/foundation.dart";

import "recipe_api.dart";
import "recipe_detail_models.dart";

class RecipeDetailController extends ChangeNotifier {
  RecipeDetailController({required this.api, required this.recipeId});

  final RecipeApi api;
  final String recipeId;

  bool isLoading = false;
  String? error;
  RecipeDetail? recipe;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      recipe = await api.getRecipeDetail(recipeId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Re-fetches without the loading state, so the screen keeps its content
  /// and scroll position (used after sign-in to pick up viewer flags).
  Future<void> reloadQuietly() async {
    try {
      recipe = await api.getRecipeDetail(recipeId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() async {
    // RefreshIndicator expects a Future<void>
    await load();
  }
}
