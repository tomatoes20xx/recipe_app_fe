import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";

// Building blocks shared by the create/edit recipe screen's sections
// (docs/create-recipe-redesign.md). Colors come from [AppTokens] only.

/// Section header: numbered circle (a check once [complete]), title and an
/// optional caption on the right.
class FormSectionHeader extends StatelessWidget {
  const FormSectionHeader({super.key, required this.number, required this.title, required this.complete, this.caption});

  final int number;
  final String title;
  final bool complete;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: complete ? t.brandInk : t.soft, shape: BoxShape.circle),
          child: complete
              // `card` is white in light mode and dark in dark mode, so the
              // check keeps its contrast on the light-green dark brandInk.
              ? Icon(Icons.check_rounded, size: 16, color: t.card)
              : Text(
                  "$number",
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.brandInk),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(width: 8),
          Text(caption!, style: TextStyle(fontSize: 12, color: t.ink2)),
        ],
      ],
    );
  }
}

/// Validation messages shown under a section header.
class FormSectionErrors extends StatelessWidget {
  const FormSectionErrors({super.key, required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in messages)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(m, style: TextStyle(fontSize: 13, color: error)),
              ),
          ],
        ),
      ),
    );
  }
}

/// White (light) / dark (dark) rounded card that holds a section's fields.
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      child: child,
    );
  }
}

/// Field label (13 w600), with a green asterisk when [required] and an
/// optional caption on the right.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key, this.required = false, this.caption});

  final String text;
  final bool required;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              children: [
                if (required)
                  TextSpan(
                    text: " *",
                    style: TextStyle(color: t.brandInk),
                  ),
              ],
            ),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
          ),
        ),
        if (caption != null) Text(caption!, style: TextStyle(fontSize: 12, color: t.ink2)),
      ],
    );
  }
}

/// The screen's text-field look: `field` fill, no outline; focused = 1.5px
/// `brand` border on `card`. 14px horizontal padding.
InputDecoration tokenInputDecoration(
  AppTokens t, {
  String? hint,
  EdgeInsetsGeometry? contentPadding,
  double radius = 12,
}) {
  final shape = OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.ink2, fontSize: 15, fontWeight: FontWeight.w400),
    filled: true,
    fillColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.focused) ? t.card : t.field),
    isDense: true,
    contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: shape,
    enabledBorder: shape,
    disabledBorder: shape,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: t.brand, width: 1.5),
    ),
  );
}

/// Text style of the screen's fields.
TextStyle tokenFieldStyle(AppTokens t) => TextStyle(fontSize: 15, color: t.ink, height: 1.3);

/// Paints a dashed rounded-rectangle border.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      dashWidth != oldDelegate.dashWidth ||
      dashSpace != oldDelegate.dashSpace ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// Tappable area with a 1.5px dashed `dashed` border.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 14,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: CustomPaint(
        // In front, so a filled box (color) doesn't hide the border.
        foregroundPainter: DashedBorderPainter(color: t.dashed, borderRadius: radius),
        child: Material(
          color: color ?? Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: child),
        ),
      ),
    );
  }
}

/// Full-width dashed "+ label" button (52 tall), e.g. "+ Add ingredient".
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DashedBox(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: t.brandInk),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.brandInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades [child] out over the last [width] px of its right edge, to hint
/// that a horizontal list scrolls.
class RightEdgeFade extends StatelessWidget {
  const RightEdgeFade({super.key, required this.child, this.width = 32});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final stop = rect.width <= 0 ? 1.0 : (1 - width / rect.width).clamp(0.0, 1.0);
        return LinearGradient(
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: [0, stop, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// Selectable pill (34–36 tall) with a ≥44 tall hit area. Selected = `soft`
/// background and `brandInk` w700 text.
class TokenChip extends StatelessWidget {
  const TokenChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
    this.height = 36,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheck;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Grows the hit area to 44 without growing the visual chip.
          padding: EdgeInsets.symmetric(vertical: ((44 - height) / 2).clamp(0, 10)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? t.soft : t.card,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: selected ? t.soft : t.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheck && selected) ...[
                  Icon(Icons.check_rounded, size: 16, color: t.brandInk),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? t.brandInk : t.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
