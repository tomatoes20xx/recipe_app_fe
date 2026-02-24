import "package:flutter/material.dart";
import "../localization/app_localizations.dart";

class DietaryPreference {
  final String tag;
  final IconData icon;
  final String Function(AppLocalizations?) getLabel;

  const DietaryPreference({
    required this.tag,
    required this.icon,
    required this.getLabel,
  });
}

final List<DietaryPreference> dietaryPreferences = [
  DietaryPreference(
    tag: "vegan",
    icon: Icons.eco,
    getLabel: (l) => l?.dietaryVegan ?? "Vegan",
  ),
  DietaryPreference(
    tag: "vegetarian",
    icon: Icons.grass,
    getLabel: (l) => l?.dietaryVegetarian ?? "Vegetarian",
  ),
  DietaryPreference(
    tag: "gluten-free",
    icon: Icons.no_food,
    getLabel: (l) => l?.dietaryGlutenFree ?? "Gluten-Free",
  ),
  DietaryPreference(
    tag: "dairy-free",
    icon: Icons.water_drop_outlined,
    getLabel: (l) => l?.dietaryDairyFree ?? "Dairy-Free",
  ),
  DietaryPreference(
    tag: "keto",
    icon: Icons.local_fire_department_outlined,
    getLabel: (l) => l?.dietaryKeto ?? "Keto",
  ),
  DietaryPreference(
    tag: "low-carb",
    icon: Icons.trending_down,
    getLabel: (l) => l?.dietaryLowCarb ?? "Low Carb",
  ),
  DietaryPreference(
    tag: "high-protein",
    icon: Icons.fitness_center,
    getLabel: (l) => l?.dietaryHighProtein ?? "High Protein",
  ),
  DietaryPreference(
    tag: "sugar-free",
    icon: Icons.block,
    getLabel: (l) => l?.dietarySugarFree ?? "Sugar-Free",
  ),
  DietaryPreference(
    tag: "nut-free",
    icon: Icons.dangerous_outlined,
    getLabel: (l) => l?.dietaryNutFree ?? "Nut-Free",
  ),
  DietaryPreference(
    tag: "paleo",
    icon: Icons.nature_people,
    getLabel: (l) => l?.dietaryPaleo ?? "Paleo",
  ),
];
