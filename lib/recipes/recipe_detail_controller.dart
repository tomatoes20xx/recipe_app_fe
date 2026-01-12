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

  Future<void> refresh() async {
    // RefreshIndicator expects a Future<void>
    await load();
  }
}
