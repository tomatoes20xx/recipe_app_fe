import "package:flutter/material.dart";
import "../localization/app_localizations.dart";

class RecipeCategory {
  final String tag;
  final IconData icon;
  final String Function(AppLocalizations?) getLabel;

  const RecipeCategory({
    required this.tag,
    required this.icon,
    required this.getLabel,
  });
}

final List<RecipeCategory> recipeCategories = [
  RecipeCategory(
    tag: "breakfast",
    icon: Icons.free_breakfast_outlined,
    getLabel: (l) => l?.categoryBreakfast ?? "Breakfast",
  ),
  RecipeCategory(
    tag: "lunch",
    icon: Icons.lunch_dining_outlined,
    getLabel: (l) => l?.categoryLunch ?? "Lunch",
  ),
  RecipeCategory(
    tag: "dinner",
    icon: Icons.dinner_dining_outlined,
    getLabel: (l) => l?.categoryDinner ?? "Dinner",
  ),
  RecipeCategory(
    tag: "dessert",
    icon: Icons.cake_outlined,
    getLabel: (l) => l?.categoryDessert ?? "Dessert",
  ),
  RecipeCategory(
    tag: "snack",
    icon: Icons.cookie_outlined,
    getLabel: (l) => l?.categorySnack ?? "Snack",
  ),
  RecipeCategory(
    tag: "appetizer",
    icon: Icons.tapas_outlined,
    getLabel: (l) => l?.categoryAppetizer ?? "Appetizer",
  ),
  RecipeCategory(
    tag: "soup",
    icon: Icons.soup_kitchen_outlined,
    getLabel: (l) => l?.categorySoup ?? "Soup",
  ),
  RecipeCategory(
    tag: "salad",
    icon: Icons.eco_outlined,
    getLabel: (l) => l?.categorySalad ?? "Salad",
  ),
  RecipeCategory(
    tag: "drinks",
    icon: Icons.local_cafe_outlined,
    getLabel: (l) => l?.categoryDrinks ?? "Drinks",
  ),
  RecipeCategory(
    tag: "quick-meals",
    icon: Icons.timer_outlined,
    getLabel: (l) => l?.categoryQuickMeals ?? "Quick Meals",
  ),
  RecipeCategory(
    tag: "healthy",
    icon: Icons.favorite_outline,
    getLabel: (l) => l?.categoryHealthy ?? "Healthy",
  ),
  RecipeCategory(
    tag: "comfort-food",
    icon: Icons.restaurant_outlined,
    getLabel: (l) => l?.categoryComfortFood ?? "Comfort Food",
  ),
];
