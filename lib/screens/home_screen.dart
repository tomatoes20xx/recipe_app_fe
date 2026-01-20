import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:cached_network_image/cached_network_image.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_api.dart";
import "../feed/feed_controller.dart";
import "../feed/feed_models.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../recipes/recipe_api.dart";
import "../recipes/comments_bottom_sheet.dart";
import "../recipes/recipe_detail_screen.dart";
import "../theme/theme_controller.dart";
import "../utils/ui_utils.dart";
import "settings_screen.dart";
import "../notifications/notification_api.dart";
import "../notifications/notification_controller.dart";
import "create_recipe_screen.dart";
import "notifications_screen.dart";
import "profile_screen.dart";
import "saved_recipes_screen.dart";
import "search_screen.dart";
import "analytics_stats_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
  });
  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _kFullScreenViewKey = "full_screen_view";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late final FeedController feed;
  late final NotificationController notificationController;
  final ScrollController sc = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

    feed = FeedController(
      feedApi: FeedApi(widget.apiClient),
      recipeApi: RecipeApi(widget.apiClient),
    );
    feed.addListener(_onFeedChanged);
    feed.loadInitial();

    // Initialize notification controller
    final notificationApi = NotificationApi(widget.apiClient);
    notificationController = NotificationController(notificationApi: notificationApi);
    notificationController.addListener(_onNotificationChanged);
    // Load unread count on init
    notificationController.refreshUnreadCount();
    // Refresh unread count periodically (every 30 seconds)
    _startNotificationPolling();

    sc.addListener(_onScroll);
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
      feed.loadMore();
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
    sc.dispose();
    _fullScreenPageController.dispose();
    feed.removeListener(_onFeedChanged);
    feed.dispose();
    notificationController.removeListener(_onNotificationChanged);
    notificationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Timer? _notificationTimer;

  void _startNotificationPolling() {
    // Poll for new notifications every 10 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && widget.auth.isLoggedIn) {
        notificationController.refreshUnreadCount();
      }
    });
  }

  void _onNotificationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showControls
                  ? AppBar(
                      elevation: 0,
                      scrolledUnderElevation: 1,
                      leading: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return IconButton(
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                            tooltip: localizations?.menu ?? "Menu",
                          );
                        },
                      ),
                      title: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.feed ?? "Feed",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          );
                        },
                      ),
                      actions: [
                        IconButton(
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CreateRecipeScreen(apiClient: widget.apiClient),
                              ),
                            );
                            if (result == true) {
                              // Recipe created successfully, refresh feed
                              feed.refresh();
                            }
                          },
                          icon: const Icon(Icons.add_rounded),
                          tooltip: AppLocalizations.of(context)?.createRecipe ?? "Create Recipe",
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Notifications button with badge
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NotificationsScreen(
                                      apiClient: widget.apiClient,
                                      auth: widget.auth,
                                    ),
                                  ),
                                );
                                // Refresh unread count when returning from notifications
                                if (mounted) {
                                  notificationController.refreshUnreadCount();
                                }
                              },
                              icon: const Icon(Icons.notifications_outlined),
                              tooltip: AppLocalizations.of(context)?.notifications ?? "Notifications",
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (notificationController.unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    notificationController.unreadCount > 99
                                        ? "99+"
                                        : notificationController.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SearchScreen(
                                  apiClient: widget.apiClient,
                                  auth: widget.auth,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.search_rounded),
                          tooltip: AppLocalizations.of(context)?.search ?? "Search",
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            onPressed: () => widget.auth.logout(),
                            icon: const Icon(Icons.logout_rounded),
                            tooltip: AppLocalizations.of(context)?.logout ?? "Logout",
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      drawer: _FeedScopeDrawer(
        feed: feed,
        auth: widget.auth,
        apiClient: widget.apiClient,
        themeController: widget.themeController,
        languageController: widget.languageController,
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showControls
                ? AnimatedSlide(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    offset: Offset.zero,
                    child: _Controls(
                      feed: feed,
                      isFullScreenView: _isFullScreenView,
                      onViewToggle: () async {
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
                            if (_fullScreenPageController.hasClients && 
                                _currentFullScreenIndex < feed.items.length) {
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
                              final targetOffset = (targetItemOffset - (viewportHeight / 2) + (estimatedCardHeight / 2))
                                  .clamp(0.0, sc.position.maxScrollExtent);
                              sc.jumpTo(targetOffset);
                            }
                          }
                        });
                      },
                      languageController: widget.languageController,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: feed.refresh,
              color: Theme.of(context).colorScheme.primary,
              child: _isFullScreenView
                  ? NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
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
                            return false;
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
                        return false;
                      },
                      child: _FullScreenFeedList(
                        feed: feed,
                        pageController: _fullScreenPageController,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        onPageChanged: (index) {
                          _currentFullScreenIndex = index;
                        },
                        onActionCompleted: () {
                          // Refresh notification count after like/bookmark actions
                          notificationController.refreshUnreadCount();
                        },
                      ),
                    )
                  : _FeedList(
                      feed: feed,
                      controller: sc,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      onActionCompleted: () {
                        // Refresh notification count after like/bookmark actions
                        notificationController.refreshUnreadCount();
                      },
                    ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.feed,
    required this.isFullScreenView,
    required this.onViewToggle,
    required this.languageController,
  });
  final FeedController feed;
  final bool isFullScreenView;
  final VoidCallback onViewToggle;
  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
              _SortDropdown(feed: feed),
              const SizedBox(width: 12),
            ],
            // Period selector for popular
            if (feed.scope == "popular")
              Builder(
                builder: (context) {
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
                },
              ),
            // Days selector for trending
            if (feed.scope == "trending")
              Builder(
                builder: (context) {
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
                },
              ),
            // Window days selector (only when sort is "top" and scope is global/following)
            if ((feed.scope == "global" || feed.scope == "following") && feed.sort == "top") ...[
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
                  );
                },
              ),
            ],
            const Spacer(),
            // View toggle button
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onViewToggle,
                      icon: Icon(isFullScreenView ? Icons.view_list_rounded : Icons.view_carousel_rounded),
                      tooltip: isFullScreenView ? (localizations?.listView ?? "List View") : (localizations?.fullScreenView ?? "Full Screen View"),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
}

class _FeedScopeDrawer extends StatelessWidget {
  const _FeedScopeDrawer({
    required this.feed,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
  });
  final FeedController feed;
  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Feed Scope",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: Icon(
                    feed.scope == "global" ? Icons.check_circle : Icons.circle_outlined,
                    color: feed.scope == "global"
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(localizations?.global ?? "Global"),
                  subtitle: Text(localizations?.seeRecipesFromEveryone ?? "See recipes from everyone"),
                  selected: feed.scope == "global",
                  onTap: () {
                    feed.setScope("global");
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: Icon(
                    feed.scope == "following" ? Icons.check_circle : Icons.circle_outlined,
                    color: feed.scope == "following"
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(localizations?.following ?? "Following"),
                  subtitle: Text(localizations?.seeRecipesFromPeopleYouFollow ?? "See recipes from people you follow"),
                  selected: feed.scope == "following",
                  enabled: auth.isLoggedIn,
                  onTap: () {
                    if (!auth.isLoggedIn) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizations?.logInToSeeFollowingFeed ?? "Log in to see Following feed")),
                      );
                      return;
                    }
                    feed.setScope("following");
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: Icon(
                    feed.scope == "popular" ? Icons.check_circle : Icons.circle_outlined,
                    color: feed.scope == "popular"
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(localizations?.popular ?? "Popular"),
                  subtitle: Text(localizations?.mostPopularRecipes ?? "Most popular recipes"),
                  selected: feed.scope == "popular",
                  onTap: () {
                    feed.setScope("popular");
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: Icon(
                    feed.scope == "trending" ? Icons.check_circle : Icons.circle_outlined,
                    color: feed.scope == "trending"
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(localizations?.trending ?? "Trending"),
                  subtitle: Text(localizations?.trendingNow ?? "Trending now"),
                  selected: feed.scope == "trending",
                  onTap: () {
                    feed.setScope("trending");
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
            const Divider(),
            if (auth.isLoggedIn) ...[
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(localizations?.savedRecipes ?? "Saved Recipes"),
                    subtitle: Text(localizations?.viewYourBookmarkedRecipes ?? "View your bookmarked recipes"),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SavedRecipesScreen(
                            apiClient: apiClient,
                            auth: auth,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return ListTile(
                    leading: const Icon(Icons.analytics_rounded),
                    title: Text(localizations?.analyticsStatistics ?? "Analytics Statistics"),
                    subtitle: Text(localizations?.viewTrackingStatistics ?? "View tracking statistics"),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnalyticsStatsScreen(
                            apiClient: apiClient,
                            auth: auth,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(localizations?.settings ?? "Settings"),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            themeController: themeController,
                            languageController: languageController,
                            auth: auth,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return ListTile(
                    leading: buildUserAvatar(
                      context,
                      auth.me?["avatar_url"]?.toString(),
                      auth.me?["username"]?.toString() ?? "",
                    ),
                    title: Text(localizations?.profile ?? "Profile"),
                    subtitle: Text(
                      auth.me?["username"] != null
                          ? "@${auth.me!["username"]}"
                          : (localizations?.viewProfile ?? "View your profile"),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                          auth: auth,
                          apiClient: apiClient,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.feed});
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.feed,
    required this.controller,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });
  final FeedController feed;
  final ScrollController controller;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  Widget build(BuildContext context) {
    if (feed.isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: 5, // Show 5 skeleton cards
        itemBuilder: (context, i) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: i == 0 ? 16 : 8,
            ),
            child: _FeedCardSkeleton(),
          );
        },
      );
    }

    if (feed.error != null && feed.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  "Error",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              feed.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ),
          Center(
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return FilledButton.icon(
                  onPressed: feed.loadInitial,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(localizations?.retry ?? "Retry"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      cacheExtent: 500, // Cache 500px worth of items off-screen for smoother scrolling
      itemCount: feed.items.length + 1, // + footer
      itemBuilder: (context, i) {
        if (i == feed.items.length) {
          if (feed.isLoadingMore) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }
          if (feed.nextCursor == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Center(
                    child: Text(
                      localizations?.noMoreItems ?? "No more items",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                    ),
                  );
                },
              ),
            );
          }
          return const SizedBox(height: 60);
        }

        final item = feed.items[i];
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: i == 0 ? 16 : 8,
            bottom: i == feed.items.length - 1 ? 0 : 0,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipeId: item.id,
                      apiClient: apiClient,
                      auth: auth,
                    ),
                  ),
                );
                // If result contains updated comment count, update the feed item
                if (result != null && result is int) {
                  feed.updateCommentCount(item.id, result);
                }
              },
              child: _FeedCard(
                item: item,
                sort: feed.sort,
                feed: feed,
                apiClient: apiClient,
                auth: auth,
                onActionCompleted: onActionCompleted,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FullScreenFeedList extends StatefulWidget {
  const _FullScreenFeedList({
    required this.feed,
    required this.pageController,
    required this.apiClient,
    required this.auth,
    this.onPageChanged,
    this.onActionCompleted,
  });
  final FeedController feed;
  final PageController pageController;
  final ApiClient apiClient;
  final AuthController auth;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onActionCompleted;

  @override
  State<_FullScreenFeedList> createState() => _FullScreenFeedListState();
}

class _FullScreenFeedListState extends State<_FullScreenFeedList> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    final newPage = widget.pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      widget.onPageChanged?.call(newPage);
      // Load more when near the end
      if (newPage >= widget.feed.items.length - 2 && widget.feed.nextCursor != null) {
        widget.feed.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feed.isLoading && widget.feed.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.feed.error != null && widget.feed.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              "Error",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.feed.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return FilledButton.icon(
                  onPressed: widget.feed.loadInitial,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(localizations?.retry ?? "Retry"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: widget.pageController,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      itemCount: widget.feed.items.length + (widget.feed.nextCursor != null ? 1 : 0),
      allowImplicitScrolling: false, // Disable pre-rendering for better performance
      onPageChanged: (index) {
        widget.onPageChanged?.call(index);
      },
      itemBuilder: (context, index) {
        if (index >= widget.feed.items.length) {
          // Loading indicator at the end
          if (widget.feed.isLoadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          return Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Center(child: Text(localizations?.noMoreItems ?? "No more items"));
            },
          );
        }

        final item = widget.feed.items[index];
        return _FullScreenFeedCard(
          item: item,
          sort: widget.feed.sort,
          feed: widget.feed,
          apiClient: widget.apiClient,
          auth: widget.auth,
          onActionCompleted: widget.onActionCompleted,
        );
      },
    );
  }
}


class _FeedCard extends StatefulWidget {
  const _FeedCard({
    required this.item,
    required this.sort,
    required this.feed,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });
  final FeedItem item;
  final String sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _isDescriptionExpanded = false;
  final GlobalKey _leftContentKey = GlobalKey();
  double? _leftContentHeight;

  void _measureLeftContent() {
    // Only measure if we don't have a cached height
    if (_leftContentHeight != null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftContentKey.currentContext != null && mounted && _leftContentHeight == null) {
        final RenderBox? box = _leftContentKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final height = box.size.height;
          if (mounted) {
            setState(() {
              _leftContentHeight = height;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Memoize expensive computations (only compute once per build)
    final date = formatDate(widget.item.createdAt);
    final firstImage = widget.item.images.isNotEmpty ? widget.item.images.first : null;
    final hasDescription = widget.item.description != null && widget.item.description!.trim().isNotEmpty;

    // Measure left content height after build (only once, cached)
    if (_leftContentHeight == null) {
      _measureLeftContent();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
                key: _leftContentKey,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username and date at the top
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  auth: widget.auth,
                                  apiClient: widget.apiClient,
                                  username: widget.item.authorUsername,
                                ),
                              ),
                            );
                          },
                          child: widget.item.authorAvatarUrl != null && widget.item.authorAvatarUrl!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  backgroundImage: CachedNetworkImageProvider(
                                    buildImageUrl(widget.item.authorAvatarUrl!),
                                    cacheKey: widget.item.authorAvatarUrl!,
                                    maxWidth: 40,
                                    maxHeight: 40,
                                  ),
                                  onBackgroundImageError: (exception, stackTrace) {
                                    // Image failed to load, will show child as fallback
                                  },
                                  child: null,
                                )
                              : CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    widget.item.authorUsername.isNotEmpty
                                        ? widget.item.authorUsername[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "@${widget.item.authorUsername}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "•",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            date,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Recipe title
                    Text(
                      widget.item.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Description (expandable)
                    if (hasDescription) ...[
                      const SizedBox(height: 10),
                      _ExpandableDescription(
                        description: widget.item.description!,
                        isExpanded: _isDescriptionExpanded,
                        onTap: () {
                          setState(() {
                            _isDescriptionExpanded = !_isDescriptionExpanded;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Stat(
                          icon: Icons.favorite_rounded,
                          value: widget.item.likes.toString(),
                          active: widget.item.viewerHasLiked,
                          onTap: () async {
                            await widget.feed.toggleLike(widget.item.id);
                            // Refresh notifications after like action
                            widget.onActionCompleted?.call();
                          },
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          icon: Icons.chat_bubble_outline_rounded,
                          value: widget.item.comments.toString(),
                          onTap: () {
                            showCommentsBottomSheet(
                              context: context,
                              recipeId: widget.item.id,
                              apiClient: widget.apiClient,
                              auth: widget.auth,
                              onCommentPosted: () {
                                widget.feed.updateCommentCount(widget.item.id, widget.item.comments + 1);
                                // Refresh notifications after comment action (with small delay for backend processing)
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  widget.onActionCompleted?.call();
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          icon: Icons.bookmark_rounded,
                          value: widget.item.bookmarks.toString(),
                          active: widget.item.viewerHasBookmarked,
                          onTap: () async {
                            await widget.feed.toggleBookmark(widget.item.id);
                            // Refresh notifications after bookmark action
                            widget.onActionCompleted?.call();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
                  width: 120,
                  height: _leftContentHeight ?? 120, // Fallback to 120 if not yet measured
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Stack(
                    clipBehavior: Clip.antiAlias,
                    children: [
                      if (firstImage != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            child: CachedNetworkImageWidget(
                              imageUrl: buildImageUrl(firstImage.url),
                              width: 120,
                              height: _leftContentHeight ?? 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                            ),
                          ),
                        ),
                      if (widget.sort == "top" && widget.item.likesWindow != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("🔥", style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  "${widget.item.likesWindow}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDescription extends StatelessWidget {
  const _ExpandableDescription({
    required this.description,
    required this.isExpanded,
    required this.onTap,
  });

  final String description;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Simple heuristic: if description is longer than ~100 chars, it likely needs expansion
    final needsExpansion = description.length > 100;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          height: 1.4,
        ) ?? const TextStyle();
    final buttonStyle = textStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );

    if (!needsExpansion) {
      return Text(
        description,
        style: textStyle,
      );
    }

    if (isExpanded) {
      // When expanded, show full text with "less" at the end
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: description,
              style: textStyle,
            ),
            const TextSpan(text: " "),
            TextSpan(
              text: "less",
              style: buttonStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Stop event propagation so clicking the button doesn't navigate
                  onTap();
                },
            ),
          ],
        ),
      );
    }

    // When collapsed, show truncated text with "more" inline
    // We need to manually truncate to ensure "more" is always visible
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure how much space " more" takes
        final moreTextPainter = TextPainter(
          text: TextSpan(text: " more", style: buttonStyle),
          textDirection: TextDirection.ltr,
        );
        moreTextPainter.layout();
        final moreWidth = moreTextPainter.width;
        
        // Create a text painter to measure text with available width (minus "more" space)
        final availableWidth = constraints.maxWidth - moreWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: availableWidth);
        
        String displayText = description;
        if (textPainter.didExceedMaxLines) {
          // Find where to cut the text at the end of the second line
          final position = textPainter.getPositionForOffset(
            Offset(availableWidth, textPainter.height),
          );
          final cutPoint = (position.offset - 3).clamp(0, description.length);
          displayText = "${description.substring(0, cutPoint).trim()}...";
        }

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: displayText,
                style: textStyle,
              ),
              const TextSpan(text: " "),
              TextSpan(
                text: "more",
                style: buttonStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // Stop event propagation so clicking the button doesn't navigate
                    onTap();
                  },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullScreenExpandableDescription extends StatelessWidget {
  const _FullScreenExpandableDescription({
    required this.description,
    required this.isExpanded,
    required this.onTap,
  });

  final String description;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Simple heuristic: if description is longer than ~100 chars, it likely needs expansion
    final needsExpansion = description.length > 100;
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.9),
      fontSize: 14,
      height: 1.4,
      shadows: const [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Colors.black54,
        ),
      ],
    );
    final buttonStyle = textStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );

    if (!needsExpansion) {
      return Text(
        description,
        style: textStyle,
      );
    }

    if (isExpanded) {
      // When expanded, show full text with "less" at the end
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: description,
              style: textStyle,
            ),
            const TextSpan(text: " "),
            TextSpan(
              text: "less",
              style: buttonStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Stop event propagation so clicking the button doesn't navigate
                  onTap();
                },
            ),
          ],
        ),
      );
    }

    // When collapsed, show truncated text with "more" inline
    // We need to manually truncate to ensure "more" is always visible
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure how much space " more" takes
        final moreTextPainter = TextPainter(
          text: TextSpan(text: " more", style: buttonStyle),
          textDirection: TextDirection.ltr,
        );
        moreTextPainter.layout();
        final moreWidth = moreTextPainter.width;
        
        // Create a text painter to measure text with available width (minus "more" space)
        final availableWidth = constraints.maxWidth - moreWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: availableWidth);
        
        String displayText = description;
        if (textPainter.didExceedMaxLines) {
          // Find where to cut the text at the end of the second line
          final position = textPainter.getPositionForOffset(
            Offset(availableWidth, textPainter.height),
          );
          final cutPoint = (position.offset - 3).clamp(0, description.length);
          displayText = "${description.substring(0, cutPoint).trim()}...";
        }

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: displayText,
                style: textStyle,
              ),
              const TextSpan(text: " "),
              TextSpan(
                text: "more",
                style: buttonStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // Stop event propagation so clicking the button doesn't navigate
                    onTap();
                  },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullScreenFeedCard extends StatefulWidget {
  const _FullScreenFeedCard({
    required this.item,
    required this.sort,
    required this.feed,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });
  final FeedItem item;
  final String sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  State<_FullScreenFeedCard> createState() => _FullScreenFeedCardState();
}

class _FullScreenFeedCardState extends State<_FullScreenFeedCard> {
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = formatDate(widget.item.createdAt);
    final hasMultipleImages = widget.item.images.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image carousel
        if (widget.item.images.isNotEmpty)
            GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipeId: widget.item.id,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                    ),
                  ),
                );
                if (result != null && result is int) {
                  widget.feed.updateCommentCount(widget.item.id, result);
                }
              },
              child: PageView.builder(
                controller: _imagePageController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.item.images.length,
                allowImplicitScrolling: false, // Disable pre-rendering for better performance
                onPageChanged: (index) {
                  if (_currentImageIndex != index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  }
                },
                itemBuilder: (context, index) {
                  final image = widget.item.images[index];
                  return CachedNetworkImageWidget(
                    imageUrl: buildImageUrl(image.url),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  );
                },
              ),
            )
        else
          GestureDetector(
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(
                    recipeId: widget.item.id,
                    apiClient: widget.apiClient,
                    auth: widget.auth,
                  ),
                ),
              );
              if (result != null && result is int) {
                widget.feed.updateCommentCount(widget.item.id, result);
              }
            },
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
            ),
          ),
        // Gradient overlay at bottom
        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
        // Content overlay
        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipeId: widget.item.id,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                    ),
                  ),
                );
                if (result != null && result is int) {
                  widget.feed.updateCommentCount(widget.item.id, result);
                }
              },
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Author info
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  auth: widget.auth,
                                  apiClient: widget.apiClient,
                                  username: widget.item.authorUsername,
                                ),
                              ),
                            );
                          },
                          child: widget.item.authorAvatarUrl != null && widget.item.authorAvatarUrl!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  backgroundImage: CachedNetworkImageProvider(
                                    buildImageUrl(widget.item.authorAvatarUrl!),
                                    cacheKey: widget.item.authorAvatarUrl!,
                                    maxWidth: 64,
                                    maxHeight: 64,
                                  ),
                                  onBackgroundImageError: (exception, stackTrace) {},
                                  child: null,
                                )
                              : CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    widget.item.authorUsername.isNotEmpty
                                        ? widget.item.authorUsername[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "@${widget.item.authorUsername}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                date,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Description
                    if (widget.item.description != null && widget.item.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _FullScreenExpandableDescription(
                        description: widget.item.description!,
                        isExpanded: _isDescriptionExpanded,
                        onTap: () {
                          setState(() {
                            _isDescriptionExpanded = !_isDescriptionExpanded;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        _FullScreenStat(
                          icon: Icons.favorite_rounded,
                          value: widget.item.likes.toString(),
                          active: widget.item.viewerHasLiked,
                          onTap: () async {
                            await widget.feed.toggleLike(widget.item.id);
                            // Refresh notifications after like action (with small delay for backend processing)
                            Future.delayed(const Duration(milliseconds: 500), () {
                              widget.onActionCompleted?.call();
                            });
                          },
                        ),
                        const SizedBox(width: 20),
                        _FullScreenStat(
                          icon: Icons.chat_bubble_outline_rounded,
                          value: widget.item.comments.toString(),
                          onTap: () {
                            showCommentsBottomSheet(
                              context: context,
                              recipeId: widget.item.id,
                              apiClient: widget.apiClient,
                              auth: widget.auth,
                              onCommentPosted: () {
                                widget.feed.updateCommentCount(widget.item.id, widget.item.comments + 1);
                                // Refresh notifications after comment action (with small delay for backend processing)
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  widget.onActionCompleted?.call();
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        _FullScreenStat(
                          icon: Icons.bookmark_rounded,
                          value: widget.item.bookmarks.toString(),
                          active: widget.item.viewerHasBookmarked,
                          onTap: () async {
                            await widget.feed.toggleBookmark(widget.item.id);
                            // Refresh notifications after bookmark action (with small delay for backend processing)
                            Future.delayed(const Duration(milliseconds: 500), () {
                              widget.onActionCompleted?.call();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                )
              ),
            ),
          ),
        // Fire badge (top sort) - top right of image
        if (widget.sort == "top" && widget.item.likesWindow != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("🔥", style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    "${widget.item.likesWindow}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Image indicator dots (if multiple images)
        if (hasMultipleImages)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.item.images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentImageIndex
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FullScreenStat extends StatelessWidget {
  const _FullScreenStat({
    required this.icon,
    required this.value,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final String value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: active ? Theme.of(context).colorScheme.primary : Colors.white,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}

class _FeedCardSkeleton extends StatelessWidget {
  const _FeedCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
                        _SkeletonBox(width: 80, height: 12),
                        const SizedBox(width: 8),
                        _SkeletonBox(width: 100, height: 12),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title skeleton
                    _SkeletonBox(width: double.infinity, height: 20),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 150, height: 20),
                    const SizedBox(height: 10),
                    // Description skeleton
                    _SkeletonBox(width: double.infinity, height: 14),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 200, height: 14),
                    const SizedBox(height: 16),
                    // Stats skeleton
                    Row(
                      children: [
                        _SkeletonBox(width: 40, height: 20),
                        const SizedBox(width: 16),
                        _SkeletonBox(width: 40, height: 20),
                        const SizedBox(width: 16),
                        _SkeletonBox(width: 40, height: 20),
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
              child: _SkeletonBox(width: 120, height: 120),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}
