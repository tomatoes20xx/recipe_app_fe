import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";
import "skeleton_pill.dart";

/// One number in a [ProfileStatsCard].
class ProfileStat {
  const ProfileStat({required this.value, required this.label, this.onTap});

  /// Null while loading (shows a skeleton).
  final int? value;
  final String label;
  final VoidCallback? onTap;
}

/// Equal-width numbers in one `card` container, split by 1px `line`
/// dividers. Used by the Profile tab and the Recipes screen.
class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final divider = VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: t.line);

    return Material(
      color: t.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) divider,
              _StatCell(stat: stats[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final value = stat.value;
    return Expanded(
      child: InkWell(
        onTap: stat.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (value == null)
                const SkeletonPill(width: 28, height: 18)
              else
                Text(
                  "$value",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
                ),
              const SizedBox(height: 2),
              Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
