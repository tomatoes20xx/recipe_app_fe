import "package:flutter/material.dart";

import "../localization/app_localizations.dart";
import "../search/filter_terms.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/app_bottom_sheet.dart";
import "../widgets/section_title_widget.dart";
import "recipe_detail_models.dart";

// The recipe page's building blocks, shared by RecipeDetailScreen and the
// create flow's RecipePreviewScreen so the preview always looks like the
// published page. Layout: photos on top, the recipe on a draggable sheet
// over them ([RecipeDetailLayout] + [RecipeDetailContent]).

/// Photos (top 60%) with the recipe on a sheet that snaps between 55% and
/// 95% of the height. [sheetChild] gets the sheet's scroll controller.
class RecipeDetailLayout extends StatelessWidget {
  const RecipeDetailLayout({super.key, required this.hero, required this.sheetChild});

  final Widget hero;
  final Widget Function(ScrollController controller) sheetChild;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        hero,
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          snap: true,
          snapSizes: const [0.55, 0.95],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: sheetChild(scrollController),
            );
          },
        ),
      ],
    );
  }
}

/// The recipe on the sheet, top to bottom. Sections the caller leaves null
/// are skipped; the spacing is the published page's.
class RecipeDetailContent extends StatelessWidget {
  const RecipeDetailContent({
    super.key,
    required this.title,
    required this.authorRow,
    this.description,
    this.engagement,
    this.quickInfo,
    this.tags = const [],
    this.ingredients,
    this.nutrition,
    this.steps = const [],
    this.footer,
  });

  final String title;
  final Widget authorRow;
  final String? description;
  final Widget? engagement;
  final Widget? quickInfo;
  final List<String> tags;
  final Widget? ingredients;
  final Widget? nutrition;
  final List<String> steps;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final description = this.description?.trim() ?? "";
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          authorRow,
          const SizedBox(height: 16),
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
          ],
          if (engagement != null) ...[
            engagement!,
            const SizedBox(height: 16),
          ],
          if (quickInfo != null) ...[
            quickInfo!,
            const SizedBox(height: 16),
          ],
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => RecipeHashtagPill(tag: tag)).toList(),
            ),
            const SizedBox(height: 28),
          ],
          if (ingredients != null) ...[
            ingredients!,
            const SizedBox(height: 16),
          ],
          if (nutrition != null) ...[
            nutrition!,
            const SizedBox(height: 24),
          ],
          if (steps.isNotEmpty) RecipeStepsSection(steps: steps),
          if (footer != null) ...[
            const SizedBox(height: 24),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Photos with a bottom gradient and page dots. [imageBuilder] draws photo
/// [index] (a network image on the page, a picked file in the preview).
class RecipeHeroImages extends StatefulWidget {
  const RecipeHeroImages({
    super.key,
    required this.count,
    required this.imageBuilder,
    this.onImageTap,
  });

  final int count;
  final Widget Function(BuildContext context, int index, double height) imageBuilder;
  final ValueChanged<int>? onImageTap;

  @override
  State<RecipeHeroImages> createState() => _RecipeHeroImagesState();
}

class _RecipeHeroImagesState extends State<RecipeHeroImages> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          if (widget.count > 0)
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: widget.count,
              itemBuilder: (context, index) => GestureDetector(
                onTap: widget.onImageTap == null ? null : () => widget.onImageTap!(index),
                child: widget.imageBuilder(context, index, height),
              ),
            )
          else
            const RecipeFallbackImage(
              width: double.infinity,
              height: double.infinity,
              iconSize: 120,
            ),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Page indicators
          if (widget.count > 1)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.count,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Author avatar, name and date. [onTap] opens their profile (none in the
/// preview).
class RecipeAuthorRow extends StatelessWidget {
  const RecipeAuthorRow({
    super.key,
    required this.username,
    required this.date,
    this.displayName,
    this.avatarUrl,
    this.onTap,
  });

  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = formatDate(context, date);
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: buildUserAvatar(context, avatarUrl, username, radius: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: displayName ?? username,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: " • $formatted",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Likes, comments, saves and shares in one row. Only a like is red; a save
/// is the filled icon in the text color, as on the feed card.
class RecipeEngagementBar extends StatelessWidget {
  const RecipeEngagementBar({
    super.key,
    required this.likes,
    required this.comments,
    required this.bookmarks,
    required this.shares,
    this.viewerHasLiked = false,
    this.viewerHasBookmarked = false,
    this.isLiking = false,
    this.isBookmarking = false,
    this.onLikeTap,
    this.onLikeLongPress,
    this.onCommentTap,
    this.onBookmarkTap,
    this.onBookmarkLongPress,
    this.onShareTap,
  });

  final int likes;
  final int comments;
  final int bookmarks;
  final int shares;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;
  final bool isLiking;
  final bool isBookmarking;
  final VoidCallback? onLikeTap;
  final VoidCallback? onLikeLongPress;
  final VoidCallback? onCommentTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EngagementButton(
            icon: viewerHasLiked ? Icons.favorite : Icons.favorite_border,
            count: likes,
            isActive: viewerHasLiked,
            isLoading: isLiking,
            onTap: onLikeTap,
            onLongPress: onLikeLongPress,
            activeColor: const Color(0xFFE53935),
          ),
        ),
        Expanded(
          child: _EngagementButton(
            icon: Icons.chat_bubble_outline,
            count: comments,
            onTap: onCommentTap,
          ),
        ),
        Expanded(
          child: _EngagementButton(
            icon: viewerHasBookmarked ? Icons.bookmark : Icons.bookmark_border,
            count: bookmarks,
            isActive: viewerHasBookmarked,
            isLoading: isBookmarking,
            onTap: onBookmarkTap,
            onLongPress: onBookmarkLongPress,
            activeColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Expanded(
          child: _EngagementButton(
            icon: Icons.share,
            count: shares,
            onTap: onShareTap,
          ),
        ),
      ],
    );
  }
}

class _EngagementButton extends StatelessWidget {
  const _EngagementButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.isLoading = false,
    this.activeColor,
  });

  final IconData icon;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isActive;
  final bool isLoading;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        onLongPress: isLoading ? null : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 22, color: color),
              const SizedBox(width: 6),
              Text(
                "$count",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Time, difficulty and servings (with a stepper that scales the amounts)
/// in one rounded bar. Without [onServingsChanged] the stepper is inert.
class RecipeQuickInfoBar extends StatelessWidget {
  const RecipeQuickInfoBar({
    super.key,
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
    this.originalServings,
    this.selectedServings,
    this.onServingsChanged,
  });

  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty;
  final int? originalServings;
  final int? selectedServings;
  final ValueChanged<int>? onServingsChanged;

  /// Whether the bar has anything to show.
  static bool hasContent({int? cookingTimeMin, int? cookingTimeMax, String? difficulty, int? servings}) =>
      cookingTimeMin != null || cookingTimeMax != null || difficulty != null || servings != null;

  String _getLocalizedDifficulty(AppLocalizations? l) {
    switch (difficulty?.toLowerCase()) {
      case "easy":
        return l?.easy ?? "Easy";
      case "medium":
        return l?.medium ?? "Medium";
      case "hard":
        return l?.hard ?? "Hard";
      default:
        return difficulty!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    final time = formatCookingTime(localizations, cookingTimeMin, cookingTimeMax);
    final hasDifficulty = difficulty != null;
    final hasServings = originalServings != null;
    if (time == null && !hasDifficulty && !hasServings) return const SizedBox.shrink();

    final divider = Container(
      width: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null)
            Expanded(
              child: _QuickInfoItem(
                icon: Icons.schedule,
                iconColor: primary,
                label: localizations?.prepTime ?? "PREP TIME",
                value: time,
              ),
            ),
          if (time != null && hasDifficulty) divider,
          if (hasDifficulty)
            Expanded(
              child: _QuickInfoItem(
                icon: Icons.bolt,
                iconColor: primary,
                label: localizations?.difficulty ?? "DIFFICULTY",
                value: _getLocalizedDifficulty(localizations),
              ),
            ),
          if ((time != null || hasDifficulty) && hasServings) divider,
          if (hasServings)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 22, color: primary),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        (localizations?.servingSize ?? "SERVINGS").toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              letterSpacing: 0.8,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            final current = selectedServings ?? originalServings!;
                            if (current > 1) onServingsChanged?.call(current - 1);
                          },
                          child: Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                            color: (selectedServings ?? originalServings!) > 1
                                ? primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${selectedServings ?? originalServings}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            final current = selectedServings ?? originalServings!;
                            if (current < 99) onServingsChanged?.call(current + 1);
                          },
                          child: Icon(Icons.add_circle_outline, size: 20, color: primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickInfoItem extends StatelessWidget {
  const _QuickInfoItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ingredient line as the recipe page shows it.
class RecipeIngredientLine {
  const RecipeIngredientLine({required this.id, required this.name, required this.amount});

  final String id;
  final String name;

  /// Quantity and unit, already scaled, e.g. "200 g". May be empty.
  final String amount;

  /// [ingredient] with its quantity multiplied by [scaleFactor].
  factory RecipeIngredientLine.fromIngredient(RecipeIngredient ingredient, double scaleFactor) {
    final unit = ingredient.unit == null ? "" : " ${ingredient.unit}";
    if (ingredient.quantity == null) {
      return RecipeIngredientLine(id: ingredient.id, name: ingredient.displayName, amount: unit.trim());
    }
    final qtyStr = formatQuantity(ingredient.quantity! * scaleFactor);
    return RecipeIngredientLine(id: ingredient.id, name: ingredient.displayName, amount: "$qtyStr$unit".trim());
  }
}

/// "Ingredients" with the item count, then one tile per line. Tapping a line
/// calls [onToggle] (shopping-list selection on the page); without it the
/// list is read-only.
class RecipeIngredientsSection extends StatelessWidget {
  const RecipeIngredientsSection({
    super.key,
    required this.lines,
    this.checkedIds = const {},
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.onToggle,
  });

  final List<RecipeIngredientLine> lines;
  final Set<String> checkedIds;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations?.ingredients ?? "Ingredients",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              "${lines.length} ${localizations?.items ?? "items"}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _IngredientTile(
                line: line,
                isChecked: checkedIds.contains(line.id),
                isSelected: selectedIds.contains(line.id),
                isSelectionMode: isSelectionMode,
                onToggle: onToggle == null ? null : () => onToggle!(line.id),
              ),
            )),
      ],
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    required this.line,
    required this.isChecked,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggle,
  });

  final RecipeIngredientLine line;
  final bool isChecked;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCheckedOrSelected = isSelectionMode ? isSelected : isChecked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelectionMode && isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isCheckedOrSelected,
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line.name,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    decoration: !isSelectionMode && isChecked ? TextDecoration.lineThrough : null,
                    color: !isSelectionMode && isChecked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (line.amount.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  line.amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Steps (n)" and the numbered steps joined by a line.
class RecipeStepsSection extends StatelessWidget {
  const RecipeStepsSection({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitleWidget(
          text: "${localizations?.steps ?? "Steps"} (${steps.length})",
          variant: SectionTitleVariant.regular,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < steps.length; i++)
          _StepCard(stepNumber: i + 1, instruction: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.instruction,
    required this.isLast,
  });

  final int stepNumber;
  final String instruction;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final lineColor = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number + vertical line
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      "$stepNumber",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Step text
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Text(
                  instruction,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tag as "#label", shown in the current language when it is one of the
/// predefined categories or dietary preferences.
class RecipeHashtagPill extends StatelessWidget {
  const RecipeHashtagPill({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // A predefined category or dietary preference, stored as its slug or as
    // the English or Georgian label: show it in the current language.
    final category = findCategory(tag);
    final dietary = findDietary(tag);
    final displayLabel = category != null
        ? category.getLabel(localizations)
        : dietary != null
            ? dietary.getLabel(localizations)
            : tag;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        "#$displayLabel",
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
