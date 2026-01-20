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
/// Shows a custom placeholder image or decorative placeholder with a recipe icon
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
      ),
      child: _buildFallbackContent(context),
    );
  }

  Widget _buildFallbackContent(BuildContext context) {
    // Use container dimensions directly to fill the space completely
    double? imageWidth = width;
    double? imageHeight = height;
    BoxFit fit = BoxFit.cover; // Fill the container completely
    
    // If dimensions are infinite, use screen size
    if (width != null && !width!.isFinite) {
      final screenSize = MediaQuery.of(context).size;
      imageWidth = screenSize.width;
    }
    if (height != null && !height!.isFinite) {
      final screenSize = MediaQuery.of(context).size;
      imageHeight = screenSize.height;
    }
    
    // If no dimensions provided, use iconSize as fallback (centered)
    if (imageWidth == null && imageHeight == null) {
      return Center(
        child: Image.asset(
          'assets/images/recipe_fallback.png',
          width: iconSize * 1.5,
          height: iconSize * 1.5,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildIconFallback(context);
          },
        ),
      );
    }
    
    return Image.asset(
      'assets/images/recipe_fallback.png',
      width: imageWidth,
      height: imageHeight,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // If custom image doesn't exist, show icon fallback
        return _buildIconFallback(context);
      },
    );
  }

  Widget _buildIconFallback(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.restaurant_menu_rounded,
          size: iconSize,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        ),
        const SizedBox(height: 8),
        Text(
          "No Image",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
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
        placeholder: (context, url) => Container(
          width: width?.isFinite == true ? width : null,
          height: height?.isFinite == true ? height : null,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: SizedBox(
              width: placeholderSize,
              height: placeholderSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          // Use fallback image for broken images
          final iconSize = _calculateIconSize(width, height);
          return RecipeFallbackImage(
            width: width?.isFinite == true ? width : null,
            height: height?.isFinite == true ? height : null,
            iconSize: iconSize,
          );
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
