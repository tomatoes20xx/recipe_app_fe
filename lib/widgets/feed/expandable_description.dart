import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "../../localization/app_localizations.dart";

/// Expandable description widget for feed cards (list view)
class ExpandableDescription extends StatelessWidget {
  const ExpandableDescription({
    super.key,
    required this.description,
    required this.isExpanded,
    required this.onTap,
  });

  final String description;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Simple heuristic: if description is longer than ~100 chars, it likely needs expansion
    final needsExpansion = description.length > 100;
    final localizations = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ) ??
        const TextStyle();
    final buttonStyle = textStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );

    if (!needsExpansion) {
      return Text(
        description,
        style: textStyle,
      );
    }

    if (isExpanded) {
      // When expanded, show full text with "less" at the end
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: description,
              style: textStyle,
            ),
            const TextSpan(text: " "),
            TextSpan(
              text: localizations?.showLess ?? "less",
              style: buttonStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Stop event propagation so clicking the button doesn't navigate
                  onTap();
                },
            ),
          ],
        ),
      );
    }

    // When collapsed, show truncated text with "more" inline
    // We need to manually truncate to ensure "more" is always visible
    final moreLabel = localizations?.showMore ?? "more";
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure how much space " more" takes
        final moreTextPainter = TextPainter(
          text: TextSpan(text: " $moreLabel", style: buttonStyle),
          textDirection: TextDirection.ltr,
        );
        moreTextPainter.layout();
        final moreWidth = moreTextPainter.width;

        // Create a text painter to measure text with available width (minus "more" space)
        final availableWidth = constraints.maxWidth - moreWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: availableWidth);

        String displayText = description;
        if (textPainter.didExceedMaxLines) {
          // Find where to cut the text at the end of the second line
          final position = textPainter.getPositionForOffset(
            Offset(availableWidth, textPainter.height),
          );
          final cutPoint = (position.offset - 3).clamp(0, description.length);
          displayText = "${description.substring(0, cutPoint).trim()}...";
        }

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: displayText,
                style: textStyle,
              ),
              const TextSpan(text: " "),
              TextSpan(
                text: moreLabel,
                style: buttonStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // Stop event propagation so clicking the button doesn't navigate
                    onTap();
                  },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Expandable description widget for full-screen feed cards
class FullScreenExpandableDescription extends StatelessWidget {
  const FullScreenExpandableDescription({
    super.key,
    required this.description,
    required this.isExpanded,
    required this.onTap,
  });

  final String description;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Simple heuristic: if description is longer than ~100 chars, it likely needs expansion
    final needsExpansion = description.length > 100;
    final localizations = AppLocalizations.of(context);
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 14,
      height: 1.4,
      shadows: const [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.black54,
        ),
      ],
    );
    final buttonStyle = textStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );

    if (!needsExpansion) {
      return Text(
        description,
        style: textStyle,
      );
    }

    if (isExpanded) {
      // When expanded, show full text with "less" at the end
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: description,
              style: textStyle,
            ),
            const TextSpan(text: " "),
            TextSpan(
              text: localizations?.showLess ?? "less",
              style: buttonStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Stop event propagation so clicking the button doesn't navigate
                  onTap();
                },
            ),
          ],
        ),
      );
    }

    // When collapsed, show truncated text with "more" inline
    // We need to manually truncate to ensure "more" is always visible
    final moreLabel = localizations?.showMore ?? "more";
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure how much space " more" takes
        final moreTextPainter = TextPainter(
          text: TextSpan(text: " $moreLabel", style: buttonStyle),
          textDirection: TextDirection.ltr,
        );
        moreTextPainter.layout();
        final moreWidth = moreTextPainter.width;

        // Create a text painter to measure text with available width (minus "more" space)
        final availableWidth = constraints.maxWidth - moreWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: availableWidth);

        String displayText = description;
        if (textPainter.didExceedMaxLines) {
          // Find where to cut the text at the end of the second line
          final position = textPainter.getPositionForOffset(
            Offset(availableWidth, textPainter.height),
          );
          final cutPoint = (position.offset - 3).clamp(0, description.length);
          displayText = "${description.substring(0, cutPoint).trim()}...";
        }

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: displayText,
                style: textStyle,
              ),
              const TextSpan(text: " "),
              TextSpan(
                text: moreLabel,
                style: buttonStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // Stop event propagation so clicking the button doesn't navigate
                    onTap();
                  },
              ),
            ],
          ),
        );
      },
    );
  }
}
