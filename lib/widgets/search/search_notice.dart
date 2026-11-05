import "package:flutter/material.dart";

/// A muted info line above search results explaining how the search was
/// adjusted (typo corrected, partial matches shown, …).
class SearchNotice extends StatelessWidget {
  const SearchNotice(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
