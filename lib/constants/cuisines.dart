import "../localization/app_localizations.dart";
import "../search/filter_terms.dart";

class CuisineOption {
  final String value;
  final String Function(AppLocalizations?) getLabel;

  const CuisineOption({
    required this.value,
    required this.getLabel,
  });
}

final List<CuisineOption> cuisineOptions = [
  CuisineOption(
    value: "Georgian",
    getLabel: (l) => l?.cuisineGeorgian ?? "Georgian",
  ),
  CuisineOption(
    value: "Italian",
    getLabel: (l) => l?.cuisineItalian ?? "Italian",
  ),
  CuisineOption(
    value: "Mexican",
    getLabel: (l) => l?.cuisineMexican ?? "Mexican",
  ),
  CuisineOption(
    value: "Chinese",
    getLabel: (l) => l?.cuisineChinese ?? "Chinese",
  ),
  CuisineOption(
    value: "Japanese",
    getLabel: (l) => l?.cuisineJapanese ?? "Japanese",
  ),
  CuisineOption(
    value: "Indian",
    getLabel: (l) => l?.cuisineIndian ?? "Indian",
  ),
  CuisineOption(
    value: "Thai",
    getLabel: (l) => l?.cuisineThai ?? "Thai",
  ),
  CuisineOption(
    value: "French",
    getLabel: (l) => l?.cuisineFrench ?? "French",
  ),
  CuisineOption(
    value: "Mediterranean",
    getLabel: (l) => l?.cuisineMediterranean ?? "Mediterranean",
  ),
  CuisineOption(
    value: "American",
    getLabel: (l) => l?.cuisineAmerican ?? "American",
  ),
  CuisineOption(
    value: "Korean",
    getLabel: (l) => l?.cuisineKorean ?? "Korean",
  ),
];

/// Look up the localized label for a cuisine, or return it as-is if not predefined.
/// Recipes store the value ("Georgian") or either language's label ("ქართული").
String getLocalizedCuisine(String value, AppLocalizations? l) {
  final option = findCuisine(value);
  return option != null ? option.getLabel(l) : value;
}
