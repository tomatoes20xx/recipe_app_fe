import "package:flutter/material.dart";

/// Unified engagement stat widget for likes, comments, bookmarks, etc.
/// Supports multiple styles: regular, full-screen, overlay, and mini
class EngagementStatWidget extends StatelessWidget {
  const EngagementStatWidget({
    super.key,
    required this.icon,
    required this.value,
    this.active = false,
    this.onTap,
    this.size = EngagementStatSize.medium,
    this.style = EngagementStatStyle.regular,
    this.showShadows = false,
  });

  /// The icon to display
  final IconData icon;
  
  /// The numeric value to display (will be converted to string)
  final dynamic value; // Can be int, String, or num
  
  /// Whether this stat is in an active state (e.g., user has liked/bookmarked)
  final bool active;
  
  /// Optional tap callback - if provided, makes the widget tappable
  final VoidCallback? onTap;
  
  /// Size variant of the stat
  final EngagementStatSize size;
  
  /// Style variant of the stat
  final EngagementStatStyle style;
  
  /// Whether to show text shadows (useful for overlay styles)
  final bool showShadows;

  @override
  Widget build(BuildContext context) {
    final statData = _getStatData(context);
    
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: statData.iconSize,
          color: statData.iconColor,
        ),
        SizedBox(width: statData.spacing),
        Text(
          value.toString(),
          style: statData.textStyle,
        ),
      ],
    );

    // If not tappable, return the child directly
    if (onTap == null) return child;

    // Apply appropriate tap handling based on style
    switch (style) {
      case EngagementStatStyle.fullScreen:
      case EngagementStatStyle.overlay:
        return GestureDetector(
          onTap: onTap,
          child: child,
        );
      case EngagementStatStyle.regular:
      case EngagementStatStyle.mini:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: child,
            ),
          ),
        );
    }
  }

  _StatData _getStatData(BuildContext context) {
    final theme = Theme.of(context);
    
    switch (style) {
      case EngagementStatStyle.fullScreen:
        return _StatData(
          iconSize: 24,
          spacing: 6,
          iconColor: active ? theme.colorScheme.primary : Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
        );
      
      case EngagementStatStyle.overlay:
        return _StatData(
          iconSize: _getIconSize(),
          spacing: 2,
          iconColor: Colors.white.withOpacity(0.9),
          textStyle: TextStyle(
            fontSize: _getFontSize(),
            color: Colors.white.withOpacity(0.9),
            shadows: showShadows ? const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
              ),
            ] : null,
          ),
        );
      
      case EngagementStatStyle.mini:
        return _StatData(
          iconSize: 14,
          spacing: 4,
          iconColor: theme.colorScheme.onSurface.withOpacity(0.6),
          textStyle: theme.textTheme.bodySmall ?? const TextStyle(),
        );
      
      case EngagementStatStyle.regular:
        return _StatData(
          iconSize: _getIconSize(),
          spacing: 6,
          iconColor: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.6),
          textStyle: TextStyle(
            fontSize: _getFontSize(),
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case EngagementStatSize.small:
        return 12;
      case EngagementStatSize.medium:
        return 20;
      case EngagementStatSize.large:
        return 24;
    }
  }

  double _getFontSize() {
    switch (size) {
      case EngagementStatSize.small:
        return 11;
      case EngagementStatSize.medium:
        return 14;
      case EngagementStatSize.large:
        return 16;
    }
  }
}

/// Size variants for engagement stats
enum EngagementStatSize {
  small,   // 12px icon, 11px text (grid overlays)
  medium,  // 20px icon, 14px text (regular feed)
  large,   // 24px icon, 16px text (full-screen)
}

/// Style variants for engagement stats
enum EngagementStatStyle {
  regular,    // Theme colors, tappable with InkWell
  fullScreen, // White text with shadows, tappable with GestureDetector
  overlay,    // White text with optional shadows (for image overlays)
  mini,       // Small, theme colors, not tappable (analytics)
}

class _StatData {
  const _StatData({
    required this.iconSize,
    required this.spacing,
    required this.iconColor,
    required this.textStyle,
  });

  final double iconSize;
  final double spacing;
  final Color iconColor;
  final TextStyle textStyle;
}
