import "package:flutter/material.dart";
import "../../feed/feed_models.dart";
import "../../utils/ui_utils.dart";

/// Reusable recipe grid card widget for displaying recipes in a grid layout.
/// Used in profile screens, search results, etc.
class RecipeGridCard extends StatelessWidget {
  const RecipeGridCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  final FeedItem recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final firstImage = recipe.images.isNotEmpty ? recipe.images.first : null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (firstImage != null)
            RecipeImageWidget(
              imageUrl: firstImage.url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 400,
              cacheHeight: 400,
            )
          else
            const RecipeFallbackImage(
              width: double.infinity,
              height: double.infinity,
              iconSize: 40,
            ),
          // Gradient overlay for better text readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Selection overlay
          if (isSelectionMode) ...[
            if (isSelected)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: 0.8),
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ],
          // Overlay content
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Stats row
                _RecipeStats(
                  likes: recipe.likes,
                  comments: recipe.comments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeStats extends StatelessWidget {
  const _RecipeStats({
    required this.likes,
    required this.comments,
  });

  final int likes;
  final int comments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.favorite,
          size: 12,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 2),
        Text(
          likes.toString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.comment_outlined,
          size: 12,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 2),
        Text(
          comments.toString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
