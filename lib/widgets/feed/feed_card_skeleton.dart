import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";
import "../common/skeletons.dart";

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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author header
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                SkeletonCircle(size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 112, height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 68, height: 10),
                  ],
                ),
              ],
            ),
          ),
          // Photo
          AspectRatio(aspectRatio: 5 / 3, child: SkeletonBone()),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                SkeletonBox(width: 220, height: 16),
                SizedBox(height: 12),
                // Time, servings, category
                SkeletonBox(width: 168, height: 10),
                SizedBox(height: 20),
                // Like, comment, save
                Row(
                  children: [
                    SkeletonBox(width: 48, height: 20),
                    SizedBox(width: 16),
                    SkeletonBox(width: 48, height: 20),
                    Spacer(),
                    SkeletonCircle(size: 22),
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
