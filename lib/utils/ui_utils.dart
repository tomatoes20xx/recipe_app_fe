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

/// Optimized cached network image widget with proper error handling, loading states, and cropping
/// Images are cropped (not stretched) to fit the container using BoxFit.cover
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
    // Calculate optimal cache dimensions if not provided
    final int? finalCacheWidth = cacheWidth ?? (width.isFinite ? (width * MediaQuery.of(context).devicePixelRatio).round() : null);
    final int? finalCacheHeight = cacheHeight ?? (height.isFinite ? (height * MediaQuery.of(context).devicePixelRatio).round() : null);

    return SizedBox(
      width: width.isFinite ? width : null,
      height: height.isFinite ? height : null,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width.isFinite ? width : null,
        height: height.isFinite ? height : null,
        memCacheWidth: finalCacheWidth,
        memCacheHeight: finalCacheHeight,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => Container(
          width: width.isFinite ? width : null,
          height: height.isFinite ? height : null,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
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
          final iconSize = width.isFinite && width > 100 ? 48.0 : 32.0;
          return Container(
            width: width.isFinite ? width : null,
            height: height.isFinite ? height : null,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    size: iconSize,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  if (width.isFinite && width > 100) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Error",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
