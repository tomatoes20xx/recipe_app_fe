import "package:flutter/material.dart";

/// Skeleton loading widget for feed cards
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image skeleton
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const SkeletonBox(
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          // Content skeleton
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row skeleton
                Row(
                  children: [
                    const SkeletonCircle(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 100, height: 14),
                          const SizedBox(height: 4),
                          const SkeletonBox(width: 140, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title skeleton
                const SkeletonBox(width: double.infinity, height: 18),
                const SizedBox(height: 6),
                // Description skeleton
                const SkeletonBox(width: double.infinity, height: 14),
                const SizedBox(height: 4),
                const SkeletonBox(width: 200, height: 14),
                const SizedBox(height: 12),
                // Engagement row skeleton
                Row(
                  children: [
                    const SkeletonBox(width: 50, height: 20),
                    const SizedBox(width: 16),
                    const SkeletonBox(width: 50, height: 20),
                    const Spacer(),
                    const SkeletonBox(width: 50, height: 20),
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
