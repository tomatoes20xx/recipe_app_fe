import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";

import "../config.dart";

/// Builds a full image URL from a relative URL or returns the URL if it's already absolute
String buildImageUrl(String relativeUrl) {
  if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
    return relativeUrl;
  }
  return "${Config.apiBaseUrl}$relativeUrl";
}

/// Memoized date formatter - cache formatted dates to avoid repeated formatting
final Map<DateTime, String> _dateCache = {};

/// Formats a DateTime to a readable string like "January 15, 2024"
String formatDate(DateTime date) {
  // Use a normalized date (without time) as cache key
  final normalizedDate = DateTime(date.year, date.month, date.day);

  return _dateCache.putIfAbsent(normalizedDate, () {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final localDate = date.toLocal();
    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year}';
  });
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// Formats a DateTime to a relative time string like "2h ago", "3d ago", etc.
/// Falls back to absolute date for older timestamps.
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime.toLocal());

  if (difference.isNegative || difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';

  final local = dateTime.toLocal();
  if (difference.inDays < 365) {
    return '${_monthAbbr[local.month - 1]} ${local.day}';
  }
  return '${_monthAbbr[local.month - 1]} ${local.day}, ${local.year}';
}

/// Builds a user avatar widget with fallback to initials or icon
Widget buildUserAvatar(
  BuildContext context,
  String? avatarUrl,
  String username, {
  double radius = 20,
}) {
  // Normalize avatarUrl: treat null, empty string, or "null" string as no avatar
  final normalizedAvatarUrl = avatarUrl == null || 
      avatarUrl.isEmpty || 
      avatarUrl == "null" 
      ? null 
      : avatarUrl;
  
  if (normalizedAvatarUrl != null && normalizedAvatarUrl.isNotEmpty) {
    final avatarSize = (radius * 2 * MediaQuery.of(context).devicePixelRatio).round();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: CachedNetworkImageProvider(
        buildImageUrl(normalizedAvatarUrl),
        cacheKey: normalizedAvatarUrl,
        maxWidth: avatarSize,
        maxHeight: avatarSize,
      ),
      onBackgroundImageError: (exception, stackTrace) {
        // Image failed to load, will show child as fallback
      },
      child: null,
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: Theme.of(context).colorScheme.primary,
    child: username.isNotEmpty
        ? Text(
            username[0].toUpperCase(),
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Icon(
            Icons.person_outline_rounded,
            size: radius,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
  );
}

/// Reusable widget for recipe fallback images
/// Shows a custom placeholder image from assets/images/recipe_fallback.png
class RecipeFallbackImage extends StatelessWidget {
  const RecipeFallbackImage({
    super.key,
    this.width,
    this.height,
    this.iconSize = 80,
  });

  final double? width;
  final double? height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    // Determine if we should expand to fill available space
    final shouldExpand = (width != null && !width!.isFinite) ||
        (height != null && !height!.isFinite);

    final image = Image.asset(
      'assets/images/recipe_fallback.png',
      fit: BoxFit.cover,
      width: shouldExpand ? null : width,
      height: shouldExpand ? null : height,
    );

    // Expand to fill container when dimensions are infinite
    if (shouldExpand) {
      return SizedBox.expand(child: image);
    }

    return image;
  }
}

/// Legacy function for backward compatibility
/// Consider using [RecipeFallbackImage] widget instead
@Deprecated('Use RecipeFallbackImage widget instead')
Widget buildRecipeFallbackImage(BuildContext context, {
  double? width,
  double? height,
  double iconSize = 80,
}) {
  return RecipeFallbackImage(
    width: width,
    height: height,
    iconSize: iconSize,
  );
}

/// Unified recipe image widget for displaying uploaded recipe images
/// Handles URL building, caching, loading states, and error fallbacks consistently
class RecipeImageWidget extends StatelessWidget {
  const RecipeImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholderSize = 24,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeOutDuration = const Duration(milliseconds: 100),
    this.showProgressIndicator = false,
  });

  /// Image URL (can be relative or absolute - will be built automatically)
  final String imageUrl;

  /// Width of the image container (null for unbounded)
  final double? width;

  /// Height of the image container (null for unbounded)
  final double? height;

  /// How the image should be fitted (default: BoxFit.cover)
  final BoxFit fit;

  /// Optional explicit cache width (auto-calculated if not provided)
  final int? cacheWidth;

  /// Optional explicit cache height (auto-calculated if not provided)
  final int? cacheHeight;

  /// Size of the loading placeholder spinner (default: 24)
  final double placeholderSize;

  /// Fade in duration (default: 200ms)
  final Duration fadeInDuration;

  /// Fade out duration (default: 100ms)
  final Duration fadeOutDuration;

  /// Show download progress indicator (default: false, uses shimmer placeholder)
  final bool showProgressIndicator;

  @override
  Widget build(BuildContext context) {
    // Build full URL from relative or absolute URL
    final fullImageUrl = buildImageUrl(imageUrl);

    // Calculate optimal cache dimensions if not provided
    final int? finalCacheWidth = cacheWidth ?? _calculateCacheDimension(width, context);
    final int? finalCacheHeight = cacheHeight ?? _calculateCacheDimension(height, context);

    return SizedBox(
      width: width?.isFinite == true ? width : null,
      height: height?.isFinite == true ? height : null,
      child: CachedNetworkImage(
        imageUrl: fullImageUrl,
        fit: fit,
        width: width?.isFinite == true ? width : null,
        height: height?.isFinite == true ? height : null,
        memCacheWidth: finalCacheWidth,
        memCacheHeight: finalCacheHeight,
        fadeInDuration: fadeInDuration,
        fadeOutDuration: fadeOutDuration,
        // Use shimmer placeholder for better progressive loading UX
        placeholder: (context, url) => _ImageShimmerPlaceholder(
          width: width,
          height: height,
        ),
        // Show download progress for large images when enabled
        progressIndicatorBuilder: showProgressIndicator
            ? (context, url, progress) => _ImageShimmerPlaceholder(
                  width: width,
                  height: height,
                  progress: progress.progress,
                )
            : null,
        errorWidget: (context, url, error) {
          // Use fallback image for broken images
          final iconSize = _calculateIconSize(width, height);
          // Wrap in SizedBox.expand when dimensions are infinite to fill the container
          final fallback = RecipeFallbackImage(
            width: width?.isFinite == true ? width : null,
            height: height?.isFinite == true ? height : null,
            iconSize: iconSize,
          );
          // If either dimension is infinite, expand to fill available space
          if ((width != null && !width!.isFinite) || (height != null && !height!.isFinite)) {
            return SizedBox.expand(child: fallback);
          }
          return fallback;
        },
      ),
    );
  }

  int? _calculateCacheDimension(double? dimension, BuildContext context) {
    if (dimension == null || !dimension.isFinite) return null;
    return (dimension * MediaQuery.of(context).devicePixelRatio).round();
  }

  double _calculateIconSize(double? width, double? height) {
    // Calculate appropriate icon size based on container dimensions
    if (width != null && width.isFinite) {
      if (width > 200) return 48.0;
      if (width > 100) return 40.0;
      return 32.0;
    }
    if (height != null && height.isFinite) {
      if (height > 200) return 48.0;
      if (height > 100) return 40.0;
      return 32.0;
    }
    return 40.0; // Default
  }
}

/// Shimmer placeholder for progressive image loading
/// Creates a smooth animated loading effect while images download
class _ImageShimmerPlaceholder extends StatefulWidget {
  const _ImageShimmerPlaceholder({
    this.width,
    this.height,
    this.progress,
  });

  final double? width;
  final double? height;
  final double? progress;

  @override
  State<_ImageShimmerPlaceholder> createState() => _ImageShimmerPlaceholderState();
}

class _ImageShimmerPlaceholderState extends State<_ImageShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = Theme.of(context).colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width?.isFinite == true ? widget.width : null,
          height: widget.height?.isFinite == true ? widget.height : null,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: widget.progress != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: widget.progress,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      if (widget.progress != null && widget.progress! > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          "${(widget.progress! * 100).toInt()}%",
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// Legacy widget for backward compatibility
/// Consider using [RecipeImageWidget] instead
@Deprecated('Use RecipeImageWidget instead')
class CachedNetworkImageWidget extends StatelessWidget {
  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    return RecipeImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }
}
