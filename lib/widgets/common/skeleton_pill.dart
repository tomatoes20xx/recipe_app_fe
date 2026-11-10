import "package:flutter/material.dart";

import "skeletons.dart";

/// Placeholder for a count that is still loading: a small round-ended bone.
class SkeletonPill extends StatelessWidget {
  const SkeletonPill({super.key, this.width = 40, this.height = 10});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SkeletonBox(width: width, height: height);
}
