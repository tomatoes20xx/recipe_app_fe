import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";

/// Skeleton loading widget for feed cards. Mirrors [FeedCard]: author header,
/// 5:3 photo, title, meta row, actions.
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = BorderRadius.circular(20);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: t.card, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                SkeletonCircle(size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 70, height: 11),
                  ],
                ),
              ],
            ),
          ),
          // Photo
          AspectRatio(
            aspectRatio: 5 / 3,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const SkeletonBox(
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                SkeletonBox(width: 220, height: 18),
                SizedBox(height: 10),
                // Time, servings, category
                SkeletonBox(width: 180, height: 14),
                SizedBox(height: 18),
                // Like, comment, save
                Row(
                  children: [
                    SkeletonBox(width: 44, height: 22),
                    SizedBox(width: 20),
                    SkeletonBox(width: 44, height: 22),
                    Spacer(),
                    SkeletonBox(width: 22, height: 22),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated skeleton box for loading states
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (0.4 * _controller.value),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}

/// Animated skeleton circle for avatar loading states
class SkeletonCircle extends StatefulWidget {
  const SkeletonCircle({
    super.key,
    required this.size,
  });

  final double size;

  @override
  State<SkeletonCircle> createState() => _SkeletonCircleState();
}

class _SkeletonCircleState extends State<SkeletonCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (0.4 * _controller.value),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
