import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../feed/feed_controller.dart";
import "../../feed/feed_models.dart";
import "../../recipes/comments_bottom_sheet.dart";
import "../../screens/profile_screen.dart";
import "../../shopping/shopping_list_controller.dart";
import "../../utils/ui_utils.dart";
import "expandable_description.dart";

/// Feed card widget for list view
class FeedCard extends StatefulWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.sort,
    required this.feed,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
    this.onActionCompleted,
  });

  final FeedItem item;
  final String sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;
  final VoidCallback? onActionCompleted;

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(context, widget.item.createdAt);
    final firstImage = widget.item.images.isNotEmpty ? widget.item.images.first : null;
    final hasDescription = widget.item.description != null && widget.item.description!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image section at top
          _ImageSection(
            item: widget.item,
            sort: widget.sort,
            firstImage: firstImage,
          ),
          // Content section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                _AuthorRow(
                  item: widget.item,
                  date: date,
                  auth: widget.auth,
                  apiClient: widget.apiClient,
                  shoppingListController: widget.shoppingListController,
                ),
                const SizedBox(height: 10),
                // Recipe title
                Text(
                  widget.item.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Description
                if (hasDescription) ...[
                  const SizedBox(height: 6),
                  ExpandableDescription(
                    description: widget.item.description!,
                    isExpanded: _isDescriptionExpanded,
                    onTap: () {
                      setState(() {
                        _isDescriptionExpanded = !_isDescriptionExpanded;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                // Engagement row
                _EngagementRow(
                  item: widget.item,
                  feed: widget.feed,
                  apiClient: widget.apiClient,
                  auth: widget.auth,
                  onActionCompleted: widget.onActionCompleted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.item,
    required this.date,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
  });

  final FeedItem item;
  final String date;
  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;

  @override
  Widget build(BuildContext context) {
    final displayName = item.authorDisplayName ?? item.authorUsername;

    return GestureDetector(
      onTap: () {
        // If viewing own profile, pass null to show edit functionality
        final isOwnProfile = auth.me?["username"]?.toString() == item.authorUsername;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              auth: auth,
              apiClient: apiClient,
              shoppingListController: shoppingListController,
              username: isOwnProfile ? null : item.authorUsername,
            ),
          ),
        );
      },
      child: Row(
        children: [
          // Avatar
          item.authorAvatarUrl != null && item.authorAvatarUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: CachedNetworkImageProvider(
                    buildImageUrl(item.authorAvatarUrl!),
                    cacheKey: item.authorAvatarUrl!,
                    maxWidth: 64,
                    maxHeight: 64,
                  ),
                  onBackgroundImageError: (exception, stackTrace) {},
                  child: null,
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    item.authorUsername.isNotEmpty ? item.authorUsername[0].toUpperCase() : "?",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
          const SizedBox(width: 10),
          // Name and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  "@${item.authorUsername} · $date",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.item,
    required this.feed,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });

  final FeedItem item;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Like button
        _EngagementButton(
          icon: item.viewerHasLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          value: item.likes,
          active: item.viewerHasLiked,
          activeColor: const Color(0xFFE53935),
          onTap: () async {
            await feed.toggleLike(item.id);
            onActionCompleted?.call();
          },
        ),
        const SizedBox(width: 16),
        // Comment button
        _EngagementButton(
          icon: Icons.comment_outlined,
          value: item.comments,
          onTap: () {
            showCommentsBottomSheet(
              context: context,
              recipeId: item.id,
              apiClient: apiClient,
              auth: auth,
              onCommentPosted: () {
                feed.updateCommentCount(item.id, item.comments + 1);
                Future.delayed(const Duration(milliseconds: 500), () {
                  onActionCompleted?.call();
                });
              },
            );
          },
        ),
        const SizedBox(width: 16),
        // Bookmark button
        _EngagementButton(
          icon: item.viewerHasBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          value: item.bookmarks,
          active: item.viewerHasBookmarked,
          activeColor: const Color(0xFFE53935),
          onTap: () async {
            await feed.toggleBookmark(item.id);
            onActionCompleted?.call();
          },
        ),
      ],
    );
  }
}

class _EngagementButton extends StatelessWidget {
  const _EngagementButton({
    required this.icon,
    required this.value,
    this.active = false,
    this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.item,
    required this.sort,
    required this.firstImage,
  });

  final FeedItem item;
  final String sort;
  final RecipeImage? firstImage;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (firstImage != null)
            RecipeImageWidget(
              imageUrl: firstImage!.url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            )
          else
            RecipeFallbackImage(
              width: double.infinity,
              height: double.infinity,
              iconSize: 48,
            ),
          // Trending badge for top sort
          if (sort == "top" && item.likesWindow != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      "${item.likesWindow}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
