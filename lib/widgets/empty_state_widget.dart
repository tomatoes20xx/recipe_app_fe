import "package:flutter/material.dart";
import "../localization/app_localizations.dart";

/// Unified empty state widget for displaying empty lists, search results, etc.
/// Supports multiple variants: simple, with card, with action button
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.wrapInCard = false,
    this.iconSize = 64,
    this.titleStyle,
    this.descriptionStyle,
  });

  /// Icon to display
  final IconData icon;
  
  /// Main title text
  final String title;
  
  /// Optional description/subtitle text
  final String? description;
  
  /// Optional action button label
  final String? actionLabel;
  
  /// Optional action button callback
  final VoidCallback? onAction;
  
  /// Whether to wrap in a Card widget
  final bool wrapInCard;
  
  /// Size of the icon (default: 64)
  final double iconSize;
  
  /// Custom title text style (optional)
  final TextStyle? titleStyle;
  
  /// Custom description text style (optional)
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: titleStyle ?? theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: descriptionStyle ?? theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ],
    );

    if (wrapInCard) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: content),
        ),
      );
    }

    return Center(child: content);
  }
}

/// Error state widget for displaying errors with retry option
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  /// Error message to display
  final String message;
  
  /// Optional retry callback
  final VoidCallback? onRetry;
  
  /// Optional custom retry button label
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            localizations?.error ?? "Error",
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel ?? (localizations?.retry ?? "Retry")),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
