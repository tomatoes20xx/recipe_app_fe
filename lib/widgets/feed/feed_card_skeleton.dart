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
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username and date skeleton
                    Row(
                      children: [
                        const SkeletonBox(width: 80, height: 12),
                        const SizedBox(width: 8),
                        const SkeletonBox(width: 100, height: 12),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title skeleton
                    const SkeletonBox(width: double.infinity, height: 20),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 150, height: 20),
                    const SizedBox(height: 10),
                    // Description skeleton
                    const SkeletonBox(width: double.infinity, height: 14),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 200, height: 14),
                    const SizedBox(height: 16),
                    // Stats skeleton
                    Row(
                      children: [
                        const SkeletonBox(width: 40, height: 20),
                        const SizedBox(width: 16),
                        const SkeletonBox(width: 40, height: 20),
                        const SizedBox(width: 16),
                        const SkeletonBox(width: 40, height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Image skeleton
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const SkeletonBox(width: 120, height: 120),
            ),
          ],
        ),
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
