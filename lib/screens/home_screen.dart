import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../constants/dietary_preferences.dart";
import "../constants/recipe_categories.dart";
import "../feed/feed_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/theme_controller.dart";
import "../widgets/feed/feed_controls.dart";
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
    required this.shoppingListController,
    required this.scrollController,
    this.onNotificationRefresh,
    this.sortDropdownKey,
    this.viewToggleKey,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final FeedController feed;
  final ShoppingListController shoppingListController;
  final ScrollController scrollController;
  final VoidCallback? onNotificationRefresh;
  final GlobalKey? sortDropdownKey;
  final GlobalKey? viewToggleKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _kFullScreenViewKey = "full_screen_view";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ScrollController get sc => widget.scrollController;
  final PageController _fullScreenPageController = PageController();
  bool _isFullScreenView = false;
  bool _showControls = true;
  double _lastScrollOffset = 0.0;
  DateTime _lastScrollTime = DateTime.now();
  DateTime _lastFullScreenScrollTime = DateTime.now();

  // Track positions when switching views
  int? _savedListIndex; // Saved index for list view (estimated from scroll position)
  int _currentFullScreenIndex = 0; // Current page index in full screen view

  @override
  void initState() {
    super.initState();
    widget.feed.addListener(_onFeedChanged);
    widget.scrollController.addListener(_onScroll);
    _loadFullScreenViewPreference();
  }

  Future<void> _loadFullScreenViewPreference() async {
    try {
      final savedPreference = await _storage.read(key: _kFullScreenViewKey);
      if (savedPreference != null && mounted) {
        setState(() {
          _isFullScreenView = savedPreference == "true";
        });
      }
    } catch (e) {
      // If loading fails, use default (false)
    }
  }

  Future<void> _saveFullScreenViewPreference(bool value) async {
    try {
      await _storage.write(key: _kFullScreenViewKey, value: value.toString());
    } catch (e) {
      // If saving fails, continue anyway
    }
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

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _fullScreenPageController.dispose();
    widget.feed.removeListener(_onFeedChanged);
    super.dispose();
  }

  void _handleViewToggle() async {
    final feed = widget.feed;
    final newValue = !_isFullScreenView;

    // Save current position before switching
    if (_isFullScreenView) {
      // Switching from full screen to list - save current page index
      _savedListIndex = _currentFullScreenIndex;
    } else {
      // Switching from list to full screen - save current scroll position
      if (sc.hasClients && feed.items.isNotEmpty) {
        // Estimate which item is currently visible based on scroll position
        // Approximate: each card is roughly 200px tall
        const estimatedCardHeight = 200.0;
        final scrollOffset = sc.position.pixels;
        final estimatedIndex = (scrollOffset / estimatedCardHeight).floor();
        _currentFullScreenIndex = estimatedIndex.clamp(0, feed.items.length - 1);
      }
    }

    setState(() {
      _isFullScreenView = newValue;
    });
    await _saveFullScreenViewPreference(newValue);

    // Restore position after switching (with a small delay to ensure widget is built)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (newValue && _currentFullScreenIndex >= 0) {
        // Switching to full screen - restore page index
        if (_fullScreenPageController.hasClients && _currentFullScreenIndex < feed.items.length) {
          _fullScreenPageController.jumpToPage(_currentFullScreenIndex);
        }
      } else if (!newValue && _savedListIndex != null) {
        // Switching to list - restore scroll position, centered in viewport
        if (sc.hasClients) {
          const estimatedCardHeight = 200.0;
          // Calculate target offset to center the item in the viewport
          final viewportHeight = MediaQuery.of(context).size.height;
          final targetItemOffset = _savedListIndex! * estimatedCardHeight;
          // Center the item by subtracting half the viewport height
          final targetOffset =
              (targetItemOffset - (viewportHeight / 2) + (estimatedCardHeight / 2))
                  .clamp(0.0, sc.position.maxScrollExtent);
          sc.jumpTo(targetOffset);
        }
      }
    });
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
              child: _isFullScreenView
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
                        onPageChanged: (index) {
                          _currentFullScreenIndex = index;
                        },
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FeedControls(
                      feed: feed,
                      isFullScreenView: _isFullScreenView,
                      onViewToggle: _handleViewToggle,
                      sortDropdownKey: widget.sortDropdownKey,
                      viewToggleKey: widget.viewToggleKey,
                    ),
                    _buildCategoryChips(feed),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryChips(FeedController feed) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: FilterChip(
              selected: feed.selectedCategory == null,
              label: Text(localizations?.allCategories ?? "All"),
              onSelected: (_) => feed.setCategory(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...recipeCategories.map((category) {
            final isSelected = feed.selectedCategory == category.tag;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: FilterChip(
                selected: isSelected,
                label: Text(category.getLabel(localizations)),
                avatar: Icon(category.icon, size: 16),
                onSelected: (_) => feed.setCategory(
                  isSelected ? null : category.tag,
                ),
                visualDensity: VisualDensity.compact,
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
            final isSelected = feed.selectedCategory == pref.tag;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: FilterChip(
                selected: isSelected,
                label: Text(pref.getLabel(localizations)),
                avatar: Icon(pref.icon, size: 16),
                onSelected: (_) => feed.setCategory(
                  isSelected ? null : pref.tag,
                ),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }
}
