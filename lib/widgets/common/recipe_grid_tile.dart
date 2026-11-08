import "package:flutter/material.dart";

import "../../feed/feed_models.dart";
import "../../theme/app_tokens.dart";
import "../../utils/ui_utils.dart";

/// Recipe photo (132px, radius 16) with its title below. Used by the Profile
/// tab's preview and the Recipes screen.
class RecipeGridTile extends StatelessWidget {
  const RecipeGridTile({super.key, required this.recipe, required this.onTap});

  final FeedItem recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final image = recipe.images.isNotEmpty ? recipe.images.first : null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: image != null
                      ? RecipeImageWidget(
                          imageUrl: image.url,
                          width: double.infinity,
                          height: 132,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                        )
                      : const RecipeFallbackImage(iconSize: 32),
                ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: RecipeGridTile(recipe: left, onTap: () => onTap(left))),
        const SizedBox(width: 12),
        Expanded(
          child: right != null
              ? RecipeGridTile(recipe: right, onTap: () => onTap(right))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
