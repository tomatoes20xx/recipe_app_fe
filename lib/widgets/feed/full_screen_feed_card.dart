import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../feed/feed_controller.dart";
import "../../feed/feed_models.dart";
import "../../recipes/comments_bottom_sheet.dart";
import "../../recipes/recipe_detail_screen.dart";
import "../../screens/profile_screen.dart";
import "../../utils/ui_utils.dart";
import "../engagement_stat_widget.dart";
import "expandable_description.dart";

/// Full-screen feed card widget (like TikTok/Instagram Reels style)
class FullScreenFeedCard extends StatefulWidget {
  const FullScreenFeedCard({
    super.key,
    required this.item,
    required this.sort,
    required this.feed,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });

  final FeedItem item;
  final String sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  State<FullScreenFeedCard> createState() => _FullScreenFeedCardState();
}

class _FullScreenFeedCardState extends State<FullScreenFeedCard> {
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _navigateToDetail() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: widget.item.id,
          apiClient: widget.apiClient,
          auth: widget.auth,
        ),
      ),
    );
    if (result != null && result is int) {
      widget.feed.updateCommentCount(widget.item.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = formatDate(widget.item.createdAt);
    final hasMultipleImages = widget.item.images.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image carousel
        _ImageCarousel(
          item: widget.item,
          pageController: _imagePageController,
          currentImageIndex: _currentImageIndex,
          onPageChanged: (index) {
            if (_currentImageIndex != index) {
              setState(() {
                _currentImageIndex = index;
              });
            }
          },
          onTap: _navigateToDetail,
        ),
        // Gradient overlay at bottom
        _GradientOverlay(),
        // Content overlay
        _ContentOverlay(
          item: widget.item,
          date: date,
          isDescriptionExpanded: _isDescriptionExpanded,
          onDescriptionToggle: () {
            setState(() {
              _isDescriptionExpanded = !_isDescriptionExpanded;
            });
          },
          onTap: _navigateToDetail,
          auth: widget.auth,
          apiClient: widget.apiClient,
        ),
        // Engagement actions overlay (right side)
        _EngagementOverlay(
          item: widget.item,
          feed: widget.feed,
          apiClient: widget.apiClient,
          auth: widget.auth,
          onActionCompleted: widget.onActionCompleted,
        ),
        // Fire badge (top sort) - top right of image
        if (widget.sort == "top" && widget.item.likesWindow != null)
          _FireBadge(likesWindow: widget.item.likesWindow!),
        // Image indicator dots (if multiple images)
        if (hasMultipleImages)
          _ImageIndicatorDots(
            imageCount: widget.item.images.length,
            currentIndex: _currentImageIndex,
          ),
      ],
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  const _ImageCarousel({
    required this.item,
    required this.pageController,
    required this.currentImageIndex,
    required this.onPageChanged,
    required this.onTap,
  });

  final FeedItem item;
  final PageController pageController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (item.images.isNotEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: PageView.builder(
          controller: pageController,
          scrollDirection: Axis.horizontal,
          itemCount: item.images.length,
          allowImplicitScrolling: false, // Disable pre-rendering for better performance
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            final image = item.images[index];
            return RecipeImageWidget(
              imageUrl: image.url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: const RecipeFallbackImage(
        width: double.infinity,
        height: double.infinity,
        iconSize: 200, // Larger size for full screen
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentOverlay extends StatelessWidget {
  const _ContentOverlay({
    required this.item,
    required this.date,
    required this.isDescriptionExpanded,
    required this.onDescriptionToggle,
    required this.onTap,
    required this.auth,
    required this.apiClient,
  });

  final FeedItem item;
  final String date;
  final bool isDescriptionExpanded;
  final VoidCallback onDescriptionToggle;
  final VoidCallback onTap;
  final AuthController auth;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: onTap,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Author info
                _AuthorInfo(
                  item: item,
                  date: date,
                  auth: auth,
                  apiClient: apiClient,
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Description
                if (item.description != null && item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FullScreenExpandableDescription(
                    description: item.description!,
                    isExpanded: isDescriptionExpanded,
                    onTap: onDescriptionToggle,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorInfo extends StatelessWidget {
  const _AuthorInfo({
    required this.item,
    required this.date,
    required this.auth,
    required this.apiClient,
  });

  final FeedItem item;
  final String date;
  final AuthController auth;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  auth: auth,
                  apiClient: apiClient,
                  username: item.authorUsername,
                ),
              ),
            );
          },
          child: item.authorAvatarUrl != null && item.authorAvatarUrl!.isNotEmpty
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
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "@${item.authorUsername}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EngagementOverlay extends StatelessWidget {
  const _EngagementOverlay({
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
    return Positioned(
      right: 16,
      bottom: 180,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EngagementStatWidget(
              icon: Icons.favorite_rounded,
              value: item.likes,
              active: item.viewerHasLiked,
              activeColor: const Color(0xFFE53935),
              size: EngagementStatSize.large,
              style: EngagementStatStyle.fullScreen,
              vertical: true,
              iconSize: 26,
              textSize: 14,
              onTap: () async {
                await feed.toggleLike(item.id);
                // Refresh notifications after like action (with small delay for backend processing)
                Future.delayed(const Duration(milliseconds: 500), () {
                  onActionCompleted?.call();
                });
              },
            ),
            const SizedBox(height: 28),
            EngagementStatWidget(
              icon: Icons.comment_outlined,
              value: item.comments,
              size: EngagementStatSize.large,
              style: EngagementStatStyle.fullScreen,
              vertical: true,
              iconSize: 26,
              textSize: 14,
              onTap: () {
                showCommentsBottomSheet(
                  context: context,
                  recipeId: item.id,
                  apiClient: apiClient,
                  auth: auth,
                  onCommentPosted: () {
                    feed.updateCommentCount(item.id, item.comments + 1);
                    // Refresh notifications after comment action (with small delay for backend processing)
                    Future.delayed(const Duration(milliseconds: 500), () {
                      onActionCompleted?.call();
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 28),
            EngagementStatWidget(
              icon: item.viewerHasBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              value: item.bookmarks,
              active: item.viewerHasBookmarked,
              activeColor: const Color(0xFFE53935),
              size: EngagementStatSize.large,
              style: EngagementStatStyle.fullScreen,
              vertical: true,
              iconSize: 26,
              textSize: 14,
              onTap: () async {
                await feed.toggleBookmark(item.id);
                // Refresh notifications after bookmark action (with small delay for backend processing)
                Future.delayed(const Duration(milliseconds: 500), () {
                  onActionCompleted?.call();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FireBadge extends StatelessWidget {
  const _FireBadge({required this.likesWindow});

  final int likesWindow;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🔥", style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              "$likesWindow",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageIndicatorDots extends StatelessWidget {
  const _ImageIndicatorDots({
    required this.imageCount,
    required this.currentIndex,
  });

  final int imageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                imageCount,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
