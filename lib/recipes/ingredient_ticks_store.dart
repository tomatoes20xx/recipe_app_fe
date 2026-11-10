import "package:shared_preferences/shared_preferences.dart";

/// Ingredients ticked off on a recipe ("I have it" / "done"), kept on the
/// phone per recipe until cleared or until the recipe is marked as cooked.
/// Shared by the recipe page and cooking mode.
class IngredientTicksStore {
  const IngredientTicksStore._();

  static String _key(String recipeId) => "ingredient_ticks_$recipeId";

  static Future<Set<String>> load(String recipeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key(recipeId)) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> save(String recipeId, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ids.isEmpty) {
        await prefs.remove(_key(recipeId));
      } else {
        await prefs.setStringList(_key(recipeId), ids.toList());
      }
    } catch (_) {
      // Ticks are a convenience; losing them is not worth an error.
    }
  }

  static Future<void> clear(String recipeId) => save(recipeId, const {});
}
