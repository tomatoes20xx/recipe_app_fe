import "package:flutter/material.dart";

import "../../feed/feed_models.dart";
import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "../../utils/ui_utils.dart";

/// Recipe photo (132px, radius 16) with its title below: the one recipe tile
/// of every grid (Profile tab, Recipes, Liked, other users' profiles, Saved,
/// collections, Shared recipes).
///
/// Pass [selected] to make it selectable (Saved, collections): a circle on
/// the photo toggles it via [onSelectTap], and a selected tile gets a `brand`
/// ring and a check.
class RecipeGridTile extends StatelessWidget {
  const RecipeGridTile({
    super.key,
    required this.recipe,
    required this.onTap,
    this.selected,
    this.onSelectTap,
  });

  final FeedItem recipe;
  final VoidCallback onTap;
  final bool? selected;
  final VoidCallback? onSelectTap;

  static const double photoHeight = 132;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final image = recipe.images.isNotEmpty ? recipe.images.first : null;
    final selected = this.selected;
    final radius = BorderRadius.circular(16);

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: SizedBox(
                      height: photoHeight,
                      width: double.infinity,
                      child: image != null
                          ? RecipeImageWidget(
                              imageUrl: image.url,
                              width: double.infinity,
                              height: photoHeight,
                              fit: BoxFit.cover,
                              cacheWidth: 400,
                            )
                          : const RecipeFallbackImage(iconSize: 32),
                    ),
                  ),
                  if (selected == true)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          color: t.brand.withValues(alpha: 0.18),
                          border: Border.all(color: t.brand, width: 3),
                        ),
                      ),
                    ),
                  if (selected != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: _SelectCircle(selected: selected, onTap: onSelectTap),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 24px select circle with a 44px tap target, on a photo.
class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l?.select ?? "Select",
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? t.fill : Colors.black.withValues(alpha: 0.25),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Two [RecipeGridTile]s side by side with a 12px gap; [right] may be null
/// for the last row of an odd list. Rows (rather than a fixed-extent grid)
/// let tiles grow with long titles and larger text.
class RecipeGridRow extends StatelessWidget {
  const RecipeGridRow({
    super.key,
    required this.left,
    required this.right,
    required this.onTap,
  });

  final FeedItem left;
  final FeedItem? right;
  final ValueChanged<FeedItem> onTap;

  @override
  Widget build(BuildContext context) {
    final right = this.right;
    return RecipeTileRow(
      left: RecipeGridTile(recipe: left, onTap: () => onTap(left)),
      right: right != null ? RecipeGridTile(recipe: right, onTap: () => onTap(right)) : null,
    );
  }
}

/// Two tiles side by side with the grid's 12px gap.
class RecipeTileRow extends StatelessWidget {
  const RecipeTileRow({super.key, required this.left, this.right});

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right ?? const SizedBox.shrink()),
      ],
    );
  }
}

/// [items] as rows of two tiles built by [tileBuilder], 16px apart: the
/// sliver form of the recipe grid.
class SliverRecipeTileGrid extends StatelessWidget {
  const SliverRecipeTileGrid({super.key, required this.items, required this.tileBuilder});

  final List<FeedItem> items;
  final Widget Function(BuildContext context, FeedItem recipe) tileBuilder;

  @override
  Widget build(BuildContext context) {
    final rows = (items.length + 1) ~/ 2;
    return SliverList.builder(
      itemCount: rows,
      itemBuilder: (context, row) {
        final i = row * 2;
        return Padding(
          padding: EdgeInsets.only(bottom: row < rows - 1 ? 16 : 0),
          child: RecipeTileRow(
            left: tileBuilder(context, items[i]),
            right: i + 1 < items.length ? tileBuilder(context, items[i + 1]) : null,
          ),
        );
      },
    );
  }
}

/// A recipe's first photo as a small rounded square (Search and Pantry
/// results), or the fallback image when there is none.
class RecipeThumb extends StatelessWidget {
  const RecipeThumb({super.key, required this.imageUrl, this.size = 64});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? RecipeImageWidget(imageUrl: url, width: size, height: size, fit: BoxFit.cover, cacheWidth: px)
            : RecipeFallbackImage(width: size, height: size),
      ),
    );
  }
}
