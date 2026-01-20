import "package:flutter/material.dart";

/// Unified section title widget for displaying section headers
/// Supports multiple variants: regular, primary, large, with padding
class SectionTitleWidget extends StatelessWidget {
  const SectionTitleWidget({
    super.key,
    required this.text,
    this.variant = SectionTitleVariant.regular,
    this.padding,
  });

  /// The text to display
  final String text;
  
  /// Visual variant of the title
  final SectionTitleVariant variant;
  
  /// Optional custom padding (defaults based on variant)
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultPadding = _getDefaultPadding();
    final style = _getTextStyle(context, theme);
    
    final textWidget = Text(
      text,
      style: style,
    );

    if (padding != null || defaultPadding != null) {
      return Padding(
        padding: padding ?? defaultPadding!,
        child: textWidget,
      );
    }

    return textWidget;
  }

  EdgeInsets? _getDefaultPadding() {
    switch (variant) {
      case SectionTitleVariant.settings:
        return const EdgeInsets.only(left: 4);
      case SectionTitleVariant.regular:
      case SectionTitleVariant.primary:
      case SectionTitleVariant.large:
        return null;
    }
  }

  TextStyle? _getTextStyle(BuildContext context, ThemeData theme) {
    switch (variant) {
      case SectionTitleVariant.regular:
        return theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );
      
      case SectionTitleVariant.primary:
        return theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        );
      
      case SectionTitleVariant.large:
        return theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        );
      
      case SectionTitleVariant.settings:
        return theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        );
    }
  }
}

/// Visual variants for section titles
enum SectionTitleVariant {
  /// Regular title (titleLarge, w600) - default
  regular,
  
  /// Primary colored title (titleMedium, w600, primary color)
  primary,
  
  /// Large bold title (titleLarge, w700, letterSpacing)
  large,
  
  /// Settings style (titleMedium, w600, primary color, left padding)
  settings,
}
