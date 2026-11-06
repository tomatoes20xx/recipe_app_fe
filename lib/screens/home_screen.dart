import "package:flutter/material.dart";

import "../analytics/analytics_service.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../constants/dietary_preferences.dart";
import "../constants/enums.dart";
import "../constants/recipe_categories.dart";
import "../feed/feed_controller.dart";
import "../feed/feed_view_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/app_tokens.dart";
import "../theme/theme_controller.dart";
import "../users/streak_controller.dart";
import "../widgets/feed/feed_list.dart";
import "../widgets/streak_celebration_overlay.dart";
import "../widgets/feed/full_screen_feed_list.dart";
import "../widgets/native_ad_manager.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.feed,
    required this.feedViewController,
    required this.shoppingListController,
    required this.scrollController,
    required this.streakController,
    required this.onStreakTap,
    this.onNotificationRefresh,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final FeedController feed;
  final FeedViewController feedViewController;
  final ShoppingListController shoppingListController;
  final ScrollController scrollController;
  final StreakController streakController;

  /// The streak chip in the header opens the Profile tab.
  final VoidCallback onStreakTap;
  final VoidCallback? onNotificationRefresh;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ScrollController get sc => widget.scrollController;
  final PageController _fullScreenPageController = PageController();
  bool _showControls = true;
  double _lastScrollOffset = 0.0;
  DateTime _lastScrollTime = DateTime.now();
  DateTime _lastFullScreenScrollTime = DateTime.now();


  @override
  void initState() {
    super.initState();
    widget.feed.addListener(_onFeedChanged);
    widget.feedViewController.addListener(_onFeedViewChanged);
    widget.scrollController.addListener(_onScroll);
    AnalyticsService().logFeedView();
  }

  void _onScroll() {
    if (!sc.hasClients) return;

    final currentOffset = sc.position.pixels;
    final currentTime = DateTime.now();
    final timeDelta = currentTime.difference(_lastScrollTime).inMilliseconds;

    // when 300px close to bottom, load more
    if (currentOffset > sc.position.maxScrollExtent - 300) {
      widget.feed.loadMore();
    }

    // Always show controls when at the top
    if (currentOffset <= 10) {
      if (!_showControls) {
        setState(() {
          _showControls = true;
        });
      }
      _lastScrollOffset = currentOffset;
      _lastScrollTime = currentTime;
      return;
    }

    // Calculate scroll speed (pixels per millisecond)
    final scrollDelta = currentOffset - _lastScrollOffset;
    final scrollSpeed = timeDelta > 0 ? (scrollDelta.abs() / timeDelta) : 0.0;

    // Fast scroll threshold: 0.5 pixels per millisecond (500 pixels per second)
    const fastScrollThreshold = 0.5;

    if (scrollDelta > 10) {
      // Scrolling down - always hide controls
      if (_showControls) {
        setState(() {
          _showControls = false;
        });
      }
    } else if (scrollDelta < -10 && scrollSpeed > fastScrollThreshold) {
      // Scrolling up fast - show controls
      if (!_showControls) {
        setState(() {
          _showControls = true;
        });
      }
    }
    // Slow scroll up - don't change controls state

    _lastScrollOffset = currentOffset;
    _lastScrollTime = currentTime;
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  void _onFeedViewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _fullScreenPageController.dispose();
    widget.feed.removeListener(_onFeedChanged);
    widget.feedViewController.removeListener(_onFeedViewChanged);
    super.dispose();
  }

  void _handleFullScreenScroll(ScrollUpdateNotification notification) {
    // Only process vertical scrolls, ignore horizontal scrolls (image carousel)
    if (notification.scrollDelta != null && notification.metrics.axis == Axis.vertical) {
      final currentOffset = notification.metrics.pixels;
      final currentTime = DateTime.now();
      final timeDelta = currentTime.difference(_lastFullScreenScrollTime).inMilliseconds;

      // Always show controls when at the top
      if (currentOffset <= 10) {
        if (!_showControls) {
          setState(() {
            _showControls = true;
          });
        }
        _lastFullScreenScrollTime = currentTime;
        return;
      }

      // Calculate scroll speed
      final scrollDelta = notification.scrollDelta!;
      final scrollSpeed = timeDelta > 0 ? (scrollDelta.abs() / timeDelta) : 0.0;

      // Fast scroll threshold: 0.5 pixels per millisecond (500 pixels per second)
      const fastScrollThreshold = 0.5;

      if (scrollDelta > 10) {
        // Scrolling down - always hide controls
        if (_showControls) {
          setState(() {
            _showControls = false;
          });
        }
      } else if (scrollDelta < -10 && scrollSpeed > fastScrollThreshold) {
        // Scrolling up fast - show controls
        if (!_showControls) {
          setState(() {
            _showControls = true;
          });
        }
      }
      // Slow scroll up - don't change controls state

      _lastFullScreenScrollTime = currentTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    // Note: Theme changes are automatically handled by Flutter's theme system.
    // No need to wrap in AnimatedBuilder for theme - only wrap specific widgets
    // that need custom animations on theme change.
    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      body: Column(
        children: [
          _buildControlsSection(feed),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh feed and ads
                await feed.refresh();
                NativeAdManager().refreshAllAds();
              },
              color: Theme.of(context).colorScheme.primary,
              child: widget.feedViewController.isFullScreenView
                  ? NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        _handleFullScreenScroll(notification);
                        return false;
                      },
                      child: FullScreenFeedList(
                        feed: feed,
                        pageController: _fullScreenPageController,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                        onPageChanged: (_) {},
                        onActionCompleted: () {
                          widget.onNotificationRefresh?.call();
                        },
                      ),
                    )
                  : FeedList(
                      feed: feed,
                      controller: sc,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                      onActionCompleted: () {
                        widget.onNotificationRefresh?.call();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(FeedController feed) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: _showControls
          ? AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              offset: Offset.zero,
              // Material (not a plain color) so the tabs' ink shows.
              child: Material(
                color: AppTokens.of(context).bg,
                child: SafeArea(
                  bottom: false,
                  child: _buildHeader(feed),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER: title row, scope tabs, sort pill + category chips.
  // Everything is derived from the FeedController; no UI copy of it.
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(FeedController feed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTitleRow(),
        _buildScopeTabs(feed),
        _buildFilterRow(feed),
      ],
    );
  }

  Widget _buildTitleRow() {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                localizations?.appTitle ?? "Yummy",
                maxLines: 1,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.brandInk),
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([widget.auth, widget.streakController]),
              builder: (context, _) {
                final streak = widget.streakController.currentStreak;
                if (!widget.auth.isLoggedIn || streak <= 0) return const SizedBox.shrink();
                return _Pill(
                  color: t.soft,
                  semanticLabel: localizations?.streakCardTitle(streak) ?? "$streak-day streak",
                  onTap: widget.onStreakTap,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 18, color: t.brandInk),
                    const SizedBox(width: 4),
                    Text(
                      "$streak",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.brandInk),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _scopeLabel(AppLocalizations? localizations, FeedScope scope) => switch (scope) {
        FeedScope.global => localizations?.feedTabForYou ?? "For you",
        FeedScope.following => localizations?.following ?? "Following",
        FeedScope.popular => localizations?.popular ?? "Popular",
        FeedScope.trending => localizations?.trending ?? "Trending",
      };

  Widget _buildScopeTabs(FeedController feed) {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Row(
        children: [
          for (final scope in FeedScope.values)
            Expanded(
              child: _ScopeTab(
                label: _scopeLabel(localizations, scope),
                isActive: feed.scope == scope,
                onTap: () => _onScopeTap(scope),
              ),
            ),
        ],
      ),
    );
  }

  /// Following has no discovery sort, so it falls back to recent. Guests are
  /// asked for an account first (as the drawer did).
  Future<void> _onScopeTap(FeedScope scope) async {
    final feed = widget.feed;
    if (feed.scope == scope) return;
    if (scope == FeedScope.following) {
      if (!await requireAccount(context, widget.auth, AccountReason.following)) return;
      if (feed.scope == FeedScope.following) return;
      feed.setScopeAndOptions(
        newScope: FeedScope.following,
        newSort: feed.sort == FeedSort.discovery ? FeedSort.recent : null,
      );
      return;
    }
    feed.setScopeAndOptions(newScope: scope);
  }

  Widget _buildFilterRow(FeedController feed) {
    final t = AppTokens.of(context);
    // Vertical padding is 8, not 12: each pill adds 4px of tap area above
    // and below its 36px body.
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
            child: _buildSortPill(feed),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: t.line),
          Expanded(child: _buildCategoryChips(feed)),
        ],
      ),
    );
  }

  Widget _buildSortPill(FeedController feed) {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);
    final options = _sortOptions(localizations);
    final current = options.firstWhere((o) => o.selected, orElse: () => options.first);
    return _Pill(
      color: t.card,
      borderColor: t.line,
      padding: 12,
      semanticLabel: "${_sortSheetTitle(localizations)}: ${current.label}",
      onTap: _showSortSheet,
      children: [
        Icon(Icons.swap_vert_rounded, size: 16, color: t.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            current.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: t.ink),
      ],
    );
  }

  /// Plain pills, no scrollbar, fading out over the last 48px on the right.
  Widget _buildCategoryChips(FeedController feed) {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);

    Widget chip(String label, bool isSelected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _Pill(
          color: isSelected ? t.soft : t.card,
          borderColor: isSelected ? null : t.line,
          selected: isSelected,
          onTap: onTap,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? t.brandInk : t.ink2,
              ),
            ),
          ],
        ),
      );
    }

    Widget toggle(String label) {
      final isSelected = feed.selectedCategory == label;
      return chip(label, isSelected, () => feed.setCategory(isSelected ? null : label));
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, rect.width > 48 ? (rect.width - 48) / rect.width : 0, 1],
      ).createShader(rect),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 40 + the last chip's 8 clears the 48px fade.
          padding: const EdgeInsets.only(left: 12, right: 40),
          child: Row(
            children: [
              chip(
                localizations?.allCategories ?? "All",
                feed.selectedCategory == null,
                () => feed.setCategory(null),
              ),
              for (final category in recipeCategories) toggle(category.getLabel(localizations)),
              // Divider between categories and dietary
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(width: 1, height: 24, color: t.line),
              ),
              for (final pref in dietaryPreferences) toggle(pref.getLabel(localizations)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SORT / PERIOD SHEET
  // ─────────────────────────────────────────────────────────────

  String _sortSheetTitle(AppLocalizations? localizations) => switch (widget.feed.scope) {
        FeedScope.global || FeedScope.following => localizations?.sortSheetTitle ?? "Sort",
        FeedScope.popular || FeedScope.trending => localizations?.periodSheetTitle ?? "Period",
      };

  /// The sort (For you, Following) or period (Popular, Trending) choices for
  /// the active tab. Each one reloads the feed through the controller, giving
  /// the same request the matching drawer option made.
  List<_SortOption> _sortOptions(AppLocalizations? localizations) {
    final feed = widget.feed;
    _SortOption sort(FeedSort value, String label, String description) => _SortOption(
          label: label,
          description: description,
          selected: feed.sort == value,
          apply: () => feed.setSort(value),
        );
    final recent = localizations?.recent ?? "Recent";
    final top = localizations?.top ?? "Top";
    final last7 = localizations?.last7Days ?? "Last 7 Days";
    final last30 = localizations?.last30Days ?? "Last 30 Days";

    switch (feed.scope) {
      case FeedScope.global:
        return [
          sort(FeedSort.discovery, localizations?.feedSortDiscovery ?? "Discovery",
              localizations?.sortDiscoveryDesc ?? "Recipes you haven't seen yet"),
          sort(FeedSort.recent, recent, localizations?.sortRecentDesc ?? "Most recently added"),
          sort(FeedSort.top, top, localizations?.sortTopDesc ?? "Most liked recipes"),
        ];
      case FeedScope.following:
        return [
          sort(FeedSort.recent, recent,
              localizations?.followingRecentDesc ?? "New recipes from people you follow"),
          sort(FeedSort.top, top, localizations?.followingTopDesc ?? "Their most liked recipes"),
        ];
      case FeedScope.popular:
        return [
          for (final (period, label) in [
            (PopularPeriod.allTime, localizations?.allTime ?? "All Time"),
            (PopularPeriod.last30Days, last30),
            (PopularPeriod.last7Days, last7),
          ])
            _SortOption(
              label: label,
              selected: feed.popularPeriod == period,
              apply: () => feed.setPopularPeriod(period),
            ),
        ];
      case FeedScope.trending:
        return [
          for (final (days, label) in [(7, last7), (30, last30)])
            _SortOption(
              label: label,
              selected: feed.trendingDays == days,
              apply: () => feed.setTrendingDays(days),
            ),
        ];
    }
  }

  void _showSortSheet() {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.sheet,
      barrierColor: t.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SortSheet(
        title: _sortSheetTitle(localizations),
        tabName: _scopeLabel(localizations, widget.feed.scope),
        options: _sortOptions(localizations),
      ),
    );
  }
}

/// Rounded 36px pill (chips, sort pill, streak chip) with a 44px tap target.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.color,
    required this.onTap,
    required this.children,
    this.borderColor,
    this.selected,
    this.semanticLabel,
    this.padding = 14,
  });

  final Color color;
  final Color? borderColor;
  final VoidCallback onTap;
  final List<Widget> children;

  /// Set for chips, so screen readers announce selected / not selected.
  final bool? selected;

  /// Replaces the children's text for screen readers.
  final String? semanticLabel;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: EdgeInsets.symmetric(horizontal: padding),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              border: borderColor != null ? Border.all(color: borderColor!) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 9),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? t.ink : t.ink2,
                ),
              ),
            ),
            // Sits directly on the row's bottom border.
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isActive ? t.brand : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.apply,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback apply;
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.title, required this.tabName, required this.options});

  final String title;
  final String tabName;
  final List<_SortOption> options;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 34 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(tabName, style: TextStyle(fontSize: 13, color: t.ink2)),
            ],
          ),
          const SizedBox(height: 8),
          for (final option in options)
            Semantics(
              button: true,
              selected: option.selected,
              inMutuallyExclusiveGroup: true,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  option.apply();
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: option.selected ? FontWeight.w700 : FontWeight.w500,
                                color: t.ink,
                              ),
                            ),
                            if (option.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                option.description!,
                                style: TextStyle(fontSize: 13, color: t.ink2),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: option.selected
                              ? Border.all(color: t.brand, width: 7)
                              : Border.all(color: t.ink2.withValues(alpha: 0.6), width: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
