import "package:flutter/gestures.dart";
import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../config.dart";
import "../feed/feed_api.dart";
import "../feed/feed_controller.dart";
import "../feed/feed_models.dart";
import "../recipes/recipe_detail_screen.dart";
import "../theme/theme_controller.dart";
import "create_recipe_screen.dart";
import "profile_screen.dart";
import "search_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
  });
  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FeedController feed;
  final ScrollController sc = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _tiktokPageController = PageController();
  bool _isTikTokView = false;
  bool _showControls = true;
  double _lastScrollOffset = 0.0;
  DateTime _lastScrollTime = DateTime.now();
  DateTime _lastTikTokScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    feed = FeedController(feedApi: FeedApi(widget.apiClient));
    feed.addListener(_onFeedChanged);
    feed.loadInitial();

    sc.addListener(_onScroll);
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
    _tiktokPageController.dispose();
    feed.removeListener(_onFeedChanged);
    feed.dispose();
    super.dispose();
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
                      leading: IconButton(
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                        tooltip: "Menu",
                      ),
                      title: Text(
                        "Feed",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
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
                          tooltip: "Create Recipe",
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
                          tooltip: "Search",
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
                            tooltip: "Logout",
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
                      isTikTokView: _isTikTokView,
                      onViewToggle: () {
                        setState(() {
                          _isTikTokView = !_isTikTokView;
                        });
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: feed.refresh,
              color: Theme.of(context).colorScheme.primary,
              child: _isTikTokView
                  ? NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        // Only process vertical scrolls, ignore horizontal scrolls (image carousel)
                        if (notification.scrollDelta != null && notification.metrics.axis == Axis.vertical) {
                          final currentOffset = notification.metrics.pixels;
                          final currentTime = DateTime.now();
                          final timeDelta = currentTime.difference(_lastTikTokScrollTime).inMilliseconds;
                          
                          // Always show controls when at the top
                          if (currentOffset <= 10) {
                            if (!_showControls) {
                              setState(() {
                                _showControls = true;
                              });
                            }
                            _lastTikTokScrollTime = currentTime;
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

                          _lastTikTokScrollTime = currentTime;
                        }
                        return false;
                      },
                      child: _TikTokFeedList(
                        feed: feed,
                        pageController: _tiktokPageController,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                      ),
                    )
                  : _FeedList(
                      feed: feed,
                      controller: sc,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
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
    required this.isTikTokView,
    required this.onViewToggle,
  });
  final FeedController feed;
  final bool isTikTokView;
  final VoidCallback onViewToggle;

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
            // Sort dropdown
            _SortDropdown(feed: feed),
            const SizedBox(width: 12),
            // Window days selector (only when sort is "top")
            if (feed.sort == "top")
              PopupMenuButton<int>(
                tooltip: "Window days",
                onSelected: (d) => feed.setWindowDays(d),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text("1 day")),
                  PopupMenuItem(value: 3, child: Text("3 days")),
                  PopupMenuItem(value: 7, child: Text("7 days")),
                  PopupMenuItem(value: 14, child: Text("14 days")),
                  PopupMenuItem(value: 30, child: Text("30 days")),
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
              ),
            const Spacer(),
            // View toggle button
            IconButton(
              onPressed: onViewToggle,
              icon: Icon(isTikTokView ? Icons.view_list_rounded : Icons.view_carousel_rounded),
              tooltip: isTikTokView ? "List View" : "TikTok View",
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
  });
  final FeedController feed;
  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Feed Scope",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AnimatedBuilder(
                    animation: themeController,
                    builder: (context, _) {
                      return Switch(
                        value: themeController.isDarkMode,
                        onChanged: (_) => themeController.toggleTheme(),
                        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                          return Icon(
                            themeController.isDarkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            size: 18,
                            color: themeController.isDarkMode
                                ? Colors.white
                                : Colors.orange,
                          );
                        }),
                        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          // Use a very light semi-transparent color instead of fully transparent
                          // This prevents grainy rendering while keeping the icon visible
                          return themeController.isDarkMode
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.08);
                        }),
                        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          return Theme.of(context).colorScheme.outline.withOpacity(0.2);
                        }),
                        trackOutlineWidth: WidgetStateProperty.resolveWith<double?>((states) {
                          return 1.0;
                        }),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                feed.scope == "global" ? Icons.check_circle : Icons.circle_outlined,
                color: feed.scope == "global"
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text("Global"),
              subtitle: const Text("See recipes from everyone"),
              selected: feed.scope == "global",
              onTap: () {
                feed.setScope("global");
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Icon(
                feed.scope == "following" ? Icons.check_circle : Icons.circle_outlined,
                color: feed.scope == "following"
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text("Following"),
              subtitle: const Text("See recipes from people you follow"),
              selected: feed.scope == "following",
              enabled: auth.isLoggedIn,
              onTap: () {
                if (!auth.isLoggedIn) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Log in to see Following feed")),
                  );
                  return;
                }
                feed.setScope("following");
                Navigator.of(context).pop();
              },
            ),
            const Divider(),
            if (auth.isLoggedIn)
              ListTile(
                leading: _buildUserAvatar(
                  context,
                  auth.me?["avatar_url"]?.toString(),
                  auth.me?["username"]?.toString() ?? "",
                ),
                title: const Text("Profile"),
                subtitle: Text(
                  auth.me?["username"] != null
                      ? "@${auth.me!["username"]}"
                      : "View your profile",
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
              ),
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
    return PopupMenuButton<String>(
      tooltip: "Sort by",
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
              const Text("Recent"),
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
              const Text("Top"),
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
              feed.sort == "recent" ? "Recent" : "Top",
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
  });
  final FeedController feed;
  final ScrollController controller;
  final ApiClient apiClient;
  final AuthController auth;

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
            child: FilledButton.icon(
              onPressed: feed.loadInitial,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
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
              child: Center(
                child: Text(
                  "No more items",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                ),
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
              child: _FeedCard(item: item, sort: feed.sort, feed: feed),
            ),
          ),
        );
      },
    );
  }
}

class _TikTokFeedList extends StatefulWidget {
  const _TikTokFeedList({
    required this.feed,
    required this.pageController,
    required this.apiClient,
    required this.auth,
  });
  final FeedController feed;
  final PageController pageController;
  final ApiClient apiClient;
  final AuthController auth;

  @override
  State<_TikTokFeedList> createState() => _TikTokFeedListState();
}

class _TikTokFeedListState extends State<_TikTokFeedList> {
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
            FilledButton.icon(
              onPressed: widget.feed.loadInitial,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
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
      itemBuilder: (context, index) {
        if (index >= widget.feed.items.length) {
          // Loading indicator at the end
          if (widget.feed.isLoadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text("No more items"));
        }

        final item = widget.feed.items[index];
        return _TikTokFeedCard(
          item: item,
          sort: widget.feed.sort,
          feed: widget.feed,
          apiClient: widget.apiClient,
          auth: widget.auth,
        );
      },
    );
  }
}

String _buildImageUrl(String relativeUrl) {
  if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
    return relativeUrl;
  }
  return "${Config.apiBaseUrl}$relativeUrl";
}

String _formatDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final localDate = date.toLocal();
  return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year}';
}

Widget _buildUserAvatar(BuildContext context, String? avatarUrl, String username) {
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: NetworkImage(_buildImageUrl(avatarUrl)),
      onBackgroundImageError: (exception, stackTrace) {
        // Image failed to load, will show child as fallback
      },
      child: null,
    );
  }
  return CircleAvatar(
    radius: 20,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    child: username.isNotEmpty
        ? Text(
            username[0].toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          )
        : Icon(
            Icons.person_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
  );
}

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.item, required this.sort, required this.feed});
  final FeedItem item;
  final String sort;
  final FeedController feed;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _isDescriptionExpanded = false;
  final GlobalKey _leftContentKey = GlobalKey();
  double? _leftContentHeight;

  void _measureLeftContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftContentKey.currentContext != null && mounted) {
        final RenderBox? box = _leftContentKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final height = box.size.height;
          if (_leftContentHeight != height) {
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
    final date = _formatDate(widget.item.createdAt);
    final firstImage = widget.item.images.isNotEmpty ? widget.item.images.first : null;
    final hasDescription = widget.item.description != null && widget.item.description!.trim().isNotEmpty;

    // Measure left content height after build
    _measureLeftContent();

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
                        widget.item.authorAvatarUrl != null && widget.item.authorAvatarUrl!.isNotEmpty
                            ? CircleAvatar(
                                radius: 10,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                backgroundImage: NetworkImage(_buildImageUrl(widget.item.authorAvatarUrl!)),
                                onBackgroundImageError: (exception, stackTrace) {
                                  // Image failed to load, will show child as fallback
                                },
                                child: null,
                              )
                            : CircleAvatar(
                                radius: 10,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  widget.item.authorUsername.isNotEmpty
                                      ? widget.item.authorUsername[0].toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                          onTap: () => widget.feed.toggleLike(widget.item.id),
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          icon: Icons.chat_bubble_outline_rounded,
                          value: widget.item.comments.toString(),
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          icon: Icons.bookmark_rounded,
                          value: widget.item.bookmarks.toString(),
                          active: widget.item.viewerHasBookmarked,
                          onTap: () => widget.feed.toggleBookmark(widget.item.id),
                        ),
                        const Spacer(),
                        if (widget.sort == "top" && widget.item.likesWindow != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "🔥",
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${widget.item.likesWindow}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
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
                  child: firstImage != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: _leftContentHeight != null
                        ? SizedBox(
                            width: 120,
                            height: _leftContentHeight!,
                            child: Image.network(
                              _buildImageUrl(firstImage.url),
                              width: 120,
                              height: _leftContentHeight!,
                              fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: _leftContentHeight!,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      size: 32,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Error",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 120,
                              height: _leftContentHeight!,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                            ),
                          )
                        : Image.network(
                            _buildImageUrl(firstImage.url),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 120,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image_rounded,
                                        size: 32,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Error",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 120,
                                height: 120,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                    )
                    : Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                        ),
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

class _TikTokFeedCard extends StatefulWidget {
  const _TikTokFeedCard({
    required this.item,
    required this.sort,
    required this.feed,
    required this.apiClient,
    required this.auth,
  });
  final FeedItem item;
  final String sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;

  @override
  State<_TikTokFeedCard> createState() => _TikTokFeedCardState();
}

class _TikTokFeedCardState extends State<_TikTokFeedCard> {
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(widget.item.createdAt);
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
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final image = widget.item.images[index];
                  return Image.network(
                    _buildImageUrl(image.url),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Error loading image",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
        else
          Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
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
                        widget.item.authorAvatarUrl != null && widget.item.authorAvatarUrl!.isNotEmpty
                            ? CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: NetworkImage(_buildImageUrl(widget.item.authorAvatarUrl!)),
                                onBackgroundImageError: (exception, stackTrace) {},
                                child: null,
                              )
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  widget.item.authorUsername.isNotEmpty
                                      ? widget.item.authorUsername[0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                      Text(
                        widget.item.description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        _TikTokStat(
                          icon: Icons.favorite_rounded,
                          value: widget.item.likes.toString(),
                          active: widget.item.viewerHasLiked,
                          onTap: () => widget.feed.toggleLike(widget.item.id),
                        ),
                        const SizedBox(width: 20),
                        _TikTokStat(
                          icon: Icons.chat_bubble_outline_rounded,
                          value: widget.item.comments.toString(),
                        ),
                        const SizedBox(width: 20),
                        _TikTokStat(
                          icon: Icons.bookmark_rounded,
                          value: widget.item.bookmarks.toString(),
                          active: widget.item.viewerHasBookmarked,
                          onTap: () => widget.feed.toggleBookmark(widget.item.id),
                        ),
                        const Spacer(),
                        if (widget.sort == "top" && widget.item.likesWindow != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "🔥",
                                  style: TextStyle(fontSize: 14),
                                ),
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
                      ],
                    ),
                  ],
                ),
                )
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

class _TikTokStat extends StatelessWidget {
  const _TikTokStat({
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
          color: active ? Colors.red : Colors.white,
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
