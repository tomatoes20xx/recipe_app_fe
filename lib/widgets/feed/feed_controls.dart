import "package:flutter/material.dart";

import "../../feed/feed_controller.dart";
import "../../localization/app_localizations.dart";

/// Controls widget for the feed (sort, period selectors, view toggle)
class FeedControls extends StatelessWidget {
  const FeedControls({
    super.key,
    required this.feed,
    required this.isFullScreenView,
    required this.onViewToggle,
    this.sortDropdownKey,
    this.viewToggleKey,
  });

  final FeedController feed;
  final bool isFullScreenView;
  final VoidCallback onViewToggle;
  final GlobalKey? sortDropdownKey;
  final GlobalKey? viewToggleKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            // Sort dropdown (only for global/following)
            if (feed.scope == "global" || feed.scope == "following") ...[
              FeedSortDropdown(key: sortDropdownKey, feed: feed),
              const SizedBox(width: 12),
            ],
            // Period selector for popular
            if (feed.scope == "popular")
              FeedPopularPeriodSelector(feed: feed),
            // Days selector for trending
            if (feed.scope == "trending")
              FeedTrendingDaysSelector(feed: feed),
            // Window days selector (only when sort is "top" and scope is global/following)
            if ((feed.scope == "global" || feed.scope == "following") && feed.sort == "top") ...[
              const SizedBox(width: 12),
              FeedWindowDaysSelector(feed: feed),
            ],
            const Spacer(),
            // View toggle button
            _ViewToggleButton(
              key: viewToggleKey,
              isFullScreenView: isFullScreenView,
              onViewToggle: onViewToggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sort dropdown for feed (Recent/Top)
class FeedSortDropdown extends StatelessWidget {
  const FeedSortDropdown({super.key, required this.feed});

  final FeedController feed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: localizations?.sortBy ?? "Sort by",
      onSelected: (value) => feed.setSort(value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: "recent",
          child: Row(
            children: [
              if (feed.sort == "recent")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.sort == "recent") const SizedBox(width: 8),
              Text(localizations?.recent ?? "Recent"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "top",
          child: Row(
            children: [
              if (feed.sort == "top")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.sort == "top") const SizedBox(width: 8),
              Text(localizations?.top ?? "Top"),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              feed.sort == "recent" ? (localizations?.recent ?? "Recent") : (localizations?.top ?? "Top"),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Popular period selector (All Time, Last 30 Days, Last 7 Days)
class FeedPopularPeriodSelector extends StatelessWidget {
  const FeedPopularPeriodSelector({super.key, required this.feed});

  final FeedController feed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: localizations?.timePeriod ?? "Time period",
      onSelected: (p) => feed.setPopularPeriod(p),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: "all_time",
          child: Row(
            children: [
              if (feed.popularPeriod == "all_time")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.popularPeriod == "all_time") const SizedBox(width: 8),
              Text(localizations?.allTime ?? "All Time"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "30d",
          child: Row(
            children: [
              if (feed.popularPeriod == "30d")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.popularPeriod == "30d") const SizedBox(width: 8),
              Text(localizations?.last30Days ?? "Last 30 Days"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "7d",
          child: Row(
            children: [
              if (feed.popularPeriod == "7d")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.popularPeriod == "7d") const SizedBox(width: 8),
              Text(localizations?.last7Days ?? "Last 7 Days"),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              feed.popularPeriod == "all_time"
                  ? (localizations?.allTime ?? "All Time")
                  : feed.popularPeriod == "30d"
                      ? (localizations?.last30Days ?? "Last 30 Days")
                      : (localizations?.last7Days ?? "Last 7 Days"),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Trending days selector (7 days, 30 days)
class FeedTrendingDaysSelector extends StatelessWidget {
  const FeedTrendingDaysSelector({super.key, required this.feed});

  final FeedController feed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      tooltip: localizations?.days ?? "Days",
      onSelected: (d) => feed.setTrendingDays(d),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 7,
          child: Row(
            children: [
              if (feed.trendingDays == 7)
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.trendingDays == 7) const SizedBox(width: 8),
              Text(localizations?.last7Days ?? "Last 7 Days"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 30,
          child: Row(
            children: [
              if (feed.trendingDays == 30)
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (feed.trendingDays == 30) const SizedBox(width: 8),
              Text(localizations?.last30Days ?? "Last 30 Days"),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              feed.trendingDays == 7
                  ? (localizations?.last7Days ?? "Last 7 Days")
                  : (localizations?.last30Days ?? "Last 30 Days"),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Window days selector for "top" sort
class FeedWindowDaysSelector extends StatelessWidget {
  const FeedWindowDaysSelector({super.key, required this.feed});

  final FeedController feed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      tooltip: localizations?.windowDays ?? "Window days",
      onSelected: (d) => feed.setWindowDays(d),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(value: 1, child: Text(localizations?.oneDay ?? "1 day")),
        PopupMenuItem(value: 3, child: Text(localizations?.threeDays ?? "3 days")),
        PopupMenuItem(value: 7, child: Text(localizations?.sevenDays ?? "7 days")),
        PopupMenuItem(value: 14, child: Text(localizations?.fourteenDays ?? "14 days")),
        PopupMenuItem(value: 30, child: Text(localizations?.thirtyDays ?? "30 days")),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${feed.windowDays}d",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    super.key,
    required this.isFullScreenView,
    required this.onViewToggle,
  });

  final bool isFullScreenView;
  final VoidCallback onViewToggle;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onViewToggle,
          icon: Icon(isFullScreenView ? Icons.view_list_rounded : Icons.view_carousel_rounded),
          tooltip: isFullScreenView
              ? (localizations?.listView ?? "List View")
              : (localizations?.fullScreenView ?? "Full Screen View"),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
