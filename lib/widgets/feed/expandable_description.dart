import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "../../localization/app_localizations.dart";

/// Expandable description widget for feed cards.
///
/// Pass a custom [textStyle] to override the default theme-based style.
class ExpandableDescription extends StatelessWidget {
  const ExpandableDescription({
    super.key,
    required this.description,
    required this.isExpanded,
    required this.onTap,
    this.textStyle,
  });

  final String description;
  final bool isExpanded;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final needsExpansion = description.length > 100;
    final localizations = AppLocalizations.of(context);
    final resolvedTextStyle = textStyle ??
        (Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ) ??
            const TextStyle());
    final buttonStyle = resolvedTextStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );

    if (!needsExpansion) {
      return Text(description, style: resolvedTextStyle);
    }

    if (isExpanded) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: description, style: resolvedTextStyle),
            const TextSpan(text: " "),
            TextSpan(
              text: localizations?.showLess ?? "less",
              style: buttonStyle,
              recognizer: TapGestureRecognizer()..onTap = onTap,
            ),
          ],
        ),
      );
    }

    final moreLabel = localizations?.showMore ?? "more";
    return LayoutBuilder(
      builder: (context, constraints) {
        final moreTextPainter = TextPainter(
          text: TextSpan(text: " $moreLabel", style: buttonStyle),
          textDirection: TextDirection.ltr,
        );
        moreTextPainter.layout();
        final moreWidth = moreTextPainter.width;

        final availableWidth = constraints.maxWidth - moreWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: description, style: resolvedTextStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: availableWidth);

        String displayText = description;
        if (textPainter.didExceedMaxLines) {
          final position = textPainter.getPositionForOffset(
            Offset(availableWidth, textPainter.height),
          );
          final cutPoint = (position.offset - 3).clamp(0, description.length);
          displayText = "${description.substring(0, cutPoint).trim()}...";
        }

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: displayText, style: resolvedTextStyle),
              const TextSpan(text: " "),
              TextSpan(
                text: moreLabel,
                style: buttonStyle,
                recognizer: TapGestureRecognizer()..onTap = onTap,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Expandable description widget for full-screen feed cards (white text with shadow).
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
    return ExpandableDescription(
      description: description,
      isExpanded: isExpanded,
      onTap: onTap,
      textStyle: const TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.9),
        fontSize: 14,
        height: 1.4,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 2,
            color: Colors.black54,
          ),
        ],
      ),
    );
  }
}
