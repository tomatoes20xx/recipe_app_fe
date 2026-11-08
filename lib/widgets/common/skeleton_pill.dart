import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";

/// Pulsing placeholder for a count that is still loading.
class SkeletonPill extends StatefulWidget {
  const SkeletonPill({super.key, this.width = 40, this.height = 10});

  final double width;
  final double height;

  @override
  State<SkeletonPill> createState() => _SkeletonPillState();
}

class _SkeletonPillState extends State<SkeletonPill> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTokens.of(context).ink2;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: _opacity.value),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
