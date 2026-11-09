import "package:flutter/material.dart";

import "../feed/feed_card_skeleton.dart";

export "../feed/feed_card_skeleton.dart" show SkeletonBox, SkeletonCircle;

/// First-load placeholder for a 2-column grid of [RecipeGridTile]s: a 132px
/// photo and a title line per tile, 12px column gap, 16px row gap.
/// Not scrollable; put it inside the screen's own scroll view.
class RecipeGridSkeleton extends StatelessWidget {
  const RecipeGridSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget tile() => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              child: SkeletonBox(width: double.infinity, height: 132),
            ),
            SizedBox(height: 8),
            SkeletonBox(width: 110, height: 14),
          ],
        );

    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < rows - 1 ? 16 : 0),
            child: Row(
              children: [
                Expanded(child: tile()),
                const SizedBox(width: 12),
                Expanded(child: tile()),
              ],
            ),
          ),
      ],
    );
  }
}

/// First-load placeholder for a list of rows with a round avatar and two
/// lines of text (users, notifications, search results).
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.count = 6, this.leadingSize = 48, this.padding});

  final int count;
  final double leadingSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SkeletonCircle(size: leadingSize),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: i.isEven ? 160 : 120, height: 14),
                        const SizedBox(height: 8),
                        SkeletonBox(width: i.isEven ? 100 : 140, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
