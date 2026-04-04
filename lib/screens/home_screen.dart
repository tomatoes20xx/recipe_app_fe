import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../constants/dietary_preferences.dart";
import "../constants/recipe_categories.dart";
import "../feed/feed_controller.dart";
import "../feed/feed_view_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/theme_controller.dart";
import "../widgets/feed/feed_list.dart";
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
      backgroundColor: Colors.transparent,
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
              child: SafeArea(
                bottom: false,
                child: _buildCategoryChips(feed),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryChips(FeedController feed) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    const chipShadow = [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: chipShadow,
              ),
              child: FilterChip(
                selected: feed.selectedCategory == null,
                label: Text(localizations?.allCategories ?? "All"),
                onSelected: (_) => feed.setCategory(null),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          ...recipeCategories.map((category) {
            final label = category.getLabel(localizations);
            final isSelected = feed.selectedCategory == label;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: chipShadow,
                ),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(label),
                  avatar: Icon(category.icon, size: 16),
                  onSelected: (_) => feed.setCategory(
                    isSelected ? null : label,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          }),
          // Divider between categories and dietary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Container(
              width: 1,
              height: 28,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          ...dietaryPreferences.map((pref) {
            final label = pref.getLabel(localizations);
            final isSelected = feed.selectedCategory == label;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: chipShadow,
                ),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(label),
                  avatar: Icon(pref.icon, size: 16),
                  onSelected: (_) => feed.setCategory(
                    isSelected ? null : label,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
