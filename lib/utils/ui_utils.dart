import "package:flutter/material.dart";

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
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: NetworkImage(buildImageUrl(avatarUrl)),
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
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // Create image widget - don't set width/height directly to avoid stretching
    // Let the SizedBox provide constraints instead
    final imageWidget = Image.network(
      imageUrl,
      fit: fit, // BoxFit.cover ensures cropping, not stretching
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // Fade in animation for loaded images
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        final containerWidth = width.isFinite ? width : null;
        final containerHeight = height.isFinite ? height : null;
        final iconSize = width.isFinite && width > 100 ? 48.0 : 32.0;
        
        return Container(
          width: containerWidth,
          height: containerHeight,
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
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        final containerWidth = width.isFinite ? width : null;
        final containerHeight = height.isFinite ? height : null;
        
        return Container(
          width: containerWidth,
          height: containerHeight,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
    
    // Wrap in SizedBox with explicit constraints to ensure proper cropping (not stretching)
    if (width.isFinite && height.isFinite) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: SizedBox.expand(
            child: imageWidget,
          ),
        ),
      );
    }
    
    // For infinite dimensions, use width/height if provided
    if (width.isFinite || height.isFinite) {
      return SizedBox(
        width: width.isFinite ? width : null,
        height: height.isFinite ? height : null,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }
}
