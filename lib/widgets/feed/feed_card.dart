import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../feed/feed_controller.dart";
import "../../feed/feed_models.dart";
import "../../recipes/comments_bottom_sheet.dart";
import "../../screens/profile_screen.dart";
import "../../utils/ui_utils.dart";
import "../engagement_stat_widget.dart";
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
    this.onActionCompleted,
  });

  final FeedItem item;
  final String sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  bool _isDescriptionExpanded = false;
  final GlobalKey _leftContentKey = GlobalKey();
  double? _leftContentHeight;

  void _measureLeftContent() {
    // Only measure if we don't have a cached height
    if (_leftContentHeight != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftContentKey.currentContext != null && mounted && _leftContentHeight == null) {
        final RenderBox? box = _leftContentKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final height = box.size.height;
          if (mounted) {
            setState(() {
              _leftContentHeight = height;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Memoize expensive computations (only compute once per build)
    final date = formatDate(widget.item.createdAt);
    final firstImage = widget.item.images.isNotEmpty ? widget.item.images.first : null;
    final hasDescription = widget.item.description != null && widget.item.description!.trim().isNotEmpty;

    // Measure left content height after build (only once, cached)
    if (_leftContentHeight == null) {
      _measureLeftContent();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                key: _leftContentKey,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username and date at the top
                    _AuthorRow(
                      item: widget.item,
                      date: date,
                      auth: widget.auth,
                      apiClient: widget.apiClient,
                    ),
                    const SizedBox(height: 10),
                    // Recipe title
                    Text(
                      widget.item.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Description (expandable)
                    if (hasDescription) ...[
                      const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
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
            ),
            _ImageSection(
              item: widget.item,
              sort: widget.sort,
              firstImage: firstImage,
              height: _leftContentHeight,
            ),
          ],
        ),
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
                  radius: 10,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: CachedNetworkImageProvider(
                    buildImageUrl(item.authorAvatarUrl!),
                    cacheKey: item.authorAvatarUrl!,
                    maxWidth: 40,
                    maxHeight: 40,
                  ),
                  onBackgroundImageError: (exception, stackTrace) {
                    // Image failed to load, will show child as fallback
                  },
                  child: null,
                )
              : CircleAvatar(
                  radius: 10,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    item.authorUsername.isNotEmpty ? item.authorUsername[0].toUpperCase() : "?",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            "@${item.authorUsername}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            "•",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
        Flexible(
          child: Text(
            date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
        EngagementStatWidget(
          icon: Icons.favorite_rounded,
          value: item.likes,
          active: item.viewerHasLiked,
          onTap: () async {
            await feed.toggleLike(item.id);
            // Refresh notifications after like action
            onActionCompleted?.call();
          },
        ),
        const SizedBox(width: 16),
        EngagementStatWidget(
          icon: Icons.chat_bubble_outline_rounded,
          value: item.comments,
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
        const SizedBox(width: 16),
        EngagementStatWidget(
          icon: Icons.bookmark_rounded,
          value: item.bookmarks,
          active: item.viewerHasBookmarked,
          onTap: () async {
            await feed.toggleBookmark(item.id);
            // Refresh notifications after bookmark action
            onActionCompleted?.call();
          },
        ),
      ],
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.item,
    required this.sort,
    required this.firstImage,
    required this.height,
  });

  final FeedItem item;
  final String sort;
  final RecipeImage? firstImage;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: height ?? 120, // Fallback to 120 if not yet measured
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          if (firstImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: RecipeImageWidget(
                  imageUrl: firstImage!.url,
                  width: 120,
                  height: height ?? 120,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: RecipeFallbackImage(
                  width: 120,
                  height: height ?? 120,
                  iconSize: 40,
                ),
              ),
            ),
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
