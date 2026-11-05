import "package:flutter/widgets.dart";

import "../constants/cuisines.dart";
import "../constants/dietary_preferences.dart";
import "../constants/recipe_categories.dart";
import "../localization/app_localizations.dart";

// Recipes store tags and cuisine as whatever label the author's app showed:
// "Breakfast" from an English UI, "საუზმე" from a Georgian one (the importer
// always writes Georgian). Filters and display therefore have to recognise
// every spelling of a predefined tag or cuisine, not just the current
// language's label.

final _en = AppLocalizations(const Locale("en"));
final _ka = AppLocalizations(const Locale("ka"));

bool _same(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// The predefined category whose slug or English/Georgian label is [tag].
RecipeCategory? findCategory(String tag) => recipeCategories
    .where((c) => _same(c.tag, tag) || _same(c.getLabel(_en), tag) || _same(c.getLabel(_ka), tag))
    .firstOrNull;

/// The predefined dietary preference whose slug or English/Georgian label is [tag].
DietaryPreference? findDietary(String tag) => dietaryPreferences
    .where((d) => _same(d.tag, tag) || _same(d.getLabel(_en), tag) || _same(d.getLabel(_ka), tag))
    .firstOrNull;

/// The predefined cuisine whose value or English/Georgian label is [cuisine].
CuisineOption? findCuisine(String cuisine) => cuisineOptions
    .where((c) => _same(c.value, cuisine) || _same(c.getLabel(_en), cuisine) || _same(c.getLabel(_ka), cuisine))
    .firstOrNull;

/// Every stored spelling of [tag] (slug, English label, Georgian label), or
/// just [tag] for a custom tag. The backend matches tags with "any of", so
/// sending all spellings finds recipes whatever language they were tagged in.
List<String> tagTerms(String tag) {
  final category = findCategory(tag);
  if (category != null) {
    return {category.tag, category.getLabel(_en), category.getLabel(_ka)}.toList();
  }
  final dietary = findDietary(tag);
  if (dietary != null) {
    return {dietary.tag, dietary.getLabel(_en), dietary.getLabel(_ka)}.toList();
  }
  return [tag];
}

/// [tagTerms] for several tags, without duplicates. Null for no tags.
List<String>? expandTags(Iterable<String>? tags) {
  if (tags == null || tags.isEmpty) return null;
  return {for (final t in tags) ...tagTerms(t)}.toList();
}

/// A cuisine filter as the backend's comma-separated list: a predefined
/// cuisine becomes "Georgian,ქართული"; custom text is sent as typed.
String? expandCuisine(String? cuisine) {
  if (cuisine == null || cuisine.trim().isEmpty) return null;
  final option = findCuisine(cuisine);
  if (option == null) return cuisine.trim();
  return {option.value, option.getLabel(_en), option.getLabel(_ka)}.join(",");
}
