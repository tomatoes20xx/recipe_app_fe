import "dart:io";

import "package:flutter/material.dart";

import "../../constants/enums.dart";
import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "../../utils/ui_utils.dart";
import "../recipe_detail_parts.dart";

/// A photo in the preview: an uploaded image ([url]) or a picked file.
class RecipePreviewImage {
  const RecipePreviewImage.url(String this.url) : filePath = null;
  const RecipePreviewImage.file(String this.filePath) : url = null;

  final String? url;
  final String? filePath;
}

class RecipePreviewIngredient {
  const RecipePreviewIngredient({required this.amount, required this.name});

  /// Amount and unit, e.g. "500 გრ"; may be empty.
  final String amount;
  final String name;
}

class RecipePreviewAuthor {
  const RecipePreviewAuthor({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;
}

/// The form's in-memory state, as the preview shows it.
class RecipePreviewData {
  const RecipePreviewData({
    required this.title,
    required this.description,
    required this.cuisine,
    required this.tags,
    required this.cookingTimeMin,
    required this.cookingTimeMax,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.images,
  });

  final String title;
  final String description;
  final String cuisine;
  final List<String> tags;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final int? servings;
  final Difficulty? difficulty;
  final List<RecipePreviewIngredient> ingredients;
  final List<String> steps;
  final List<RecipePreviewImage> images;
}

/// Read-only look at the recipe before publishing, built from the form (the
/// real detail screen loads by id). Pops `true` when the user taps the
/// primary button, so the form runs its own submit; anything else means
/// "back to editing".
class RecipePreviewScreen extends StatefulWidget {
  const RecipePreviewScreen({super.key, required this.data, required this.primaryLabel, required this.author});

  final RecipePreviewData data;
  final String primaryLabel;
  final Future<RecipePreviewAuthor?> author;

  @override
  State<RecipePreviewScreen> createState() => _RecipePreviewScreenState();
}

class _RecipePreviewScreenState extends State<RecipePreviewScreen> {
  /// The published page's layout and parts (recipe_detail_parts.dart), fed
  /// from the form. Counts start at zero and nothing is tappable; nutrition
  /// and "Made it" need the published recipe, so they are left out.
  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _Banner(onBack: () => Navigator.of(context).pop(false)),
          Expanded(
            child: RecipeDetailLayout(
              hero: RecipeHeroImages(
                count: d.images.length,
                imageBuilder: (context, index, height) {
                  final img = d.images[index];
                  return img.url != null
                      ? RecipeImageWidget(imageUrl: img.url!, width: double.infinity, height: height, fit: BoxFit.cover)
                      : Image.file(File(img.filePath!), fit: BoxFit.cover, width: double.infinity, height: height);
                },
              ),
              sheetChild: (scrollController) => SingleChildScrollView(
                controller: scrollController,
                child: RecipeDetailContent(
                  title: d.title,
                  authorRow: FutureBuilder<RecipePreviewAuthor?>(
                    future: widget.author,
                    builder: (context, snap) {
                      final author = snap.data;
                      if (author == null) return const SizedBox(height: 28);
                      return RecipeAuthorRow(
                        username: author.name,
                        avatarUrl: author.avatarUrl,
                        date: DateTime.now(),
                      );
                    },
                  ),
                  description: d.description,
                  engagement: const IgnorePointer(
                    child: RecipeEngagementBar(likes: 0, comments: 0, bookmarks: 0, shares: 0),
                  ),
                  quickInfo: RecipeQuickInfoBar.hasContent(
                    cookingTimeMin: d.cookingTimeMin,
                    cookingTimeMax: d.cookingTimeMax,
                    difficulty: d.difficulty?.apiValue,
                    servings: d.servings,
                  )
                      ? IgnorePointer(
                          child: RecipeQuickInfoBar(
                            cookingTimeMin: d.cookingTimeMin,
                            cookingTimeMax: d.cookingTimeMax,
                            difficulty: d.difficulty?.apiValue,
                            originalServings: d.servings,
                          ),
                        )
                      : null,
                  startCooking: d.steps.isEmpty
                      ? null
                      : IgnorePointer(child: RecipeStartCookingButton(onPressed: () {})),
                  tags: d.tags,
                  ingredients: d.ingredients.isEmpty
                      ? null
                      : IgnorePointer(
                          child: RecipeIngredientsSection(
                            lines: [
                              for (var i = 0; i < d.ingredients.length; i++)
                                RecipeIngredientLine(
                                  id: "$i",
                                  name: d.ingredients[i].name,
                                  amount: d.ingredients[i].amount,
                                ),
                            ],
                            // Enabled like the page's (a null callback greys the checkboxes
                            // out) and with its header button; IgnorePointer keeps it inert.
                            onToggle: (_) {},
                            onAddToShoppingList: () {},
                          ),
                        ),
                  steps: d.steps,
                ),
              ),
            ),
          ),
          _BottomBar(
            primaryLabel: widget.primaryLabel,
            onEdit: () => Navigator.of(context).pop(false),
            onPrimary: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      color: t.soft,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(Icons.arrow_back_rounded, color: t.ink),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l?.preview ?? "Preview",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                ),
                Text(
                  l?.previewSubtitle ?? "This is how others will see it",
                  style: TextStyle(fontSize: 12, color: t.brandInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.primaryLabel, required this.onEdit, required this.onPrimary});

  final String primaryLabel;
  final VoidCallback onEdit;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (bottom > 0 ? bottom : 16)),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: t.ink,
                side: BorderSide(color: t.line),
                shape: shape,
              ),
              child: Text(l?.edit ?? "Edit", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                shape: shape,
              ),
              child: Text(
                primaryLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
