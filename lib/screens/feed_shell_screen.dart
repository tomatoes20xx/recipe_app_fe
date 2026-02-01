import "dart:async";

import "package:flutter/material.dart";
import "package:animations/animations.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_api.dart";
import "../feed/feed_controller.dart";
import "../recipes/recipe_api.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../notifications/notification_api.dart";
import "../notifications/notification_controller.dart";
import "../theme/theme_controller.dart";
import "../utils/ui_utils.dart";
import "analytics_stats_screen.dart";
import "create_recipe_screen.dart";
import "home_screen.dart";
import "notifications_screen.dart";
import "profile_screen.dart";
import "saved_recipes_screen.dart";
import "search_screen.dart";
import "settings_screen.dart";

class FeedShellScreen extends StatefulWidget {
  const FeedShellScreen({
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
  State<FeedShellScreen> createState() => _FeedShellScreenState();
}

class _FeedShellScreenState extends State<FeedShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final FeedController feed;
  int _currentIndex = 0;
  int _previousIndex = 0;

  late final NotificationController _notificationController;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    feed = FeedController(
      feedApi: FeedApi(widget.apiClient),
      recipeApi: RecipeApi(widget.apiClient),
    );
    feed.loadInitial();

    final notificationApi = NotificationApi(widget.apiClient);
    _notificationController = NotificationController(notificationApi: notificationApi);
    _notificationController.addListener(_onNotificationChanged);
    _notificationController.refreshUnreadCount();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    feed.dispose();
    _notificationController.removeListener(_onNotificationChanged);
    _notificationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _onNotificationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startNotificationPolling() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && widget.auth.isLoggedIn) {
        _notificationController.refreshUnreadCount();
      }
    });
  }

  void _setPage(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  void _changeFeedScope(String scope) {
    setState(() {
      feed.setScope(scope);
      if (_currentIndex != 0) {
        _previousIndex = _currentIndex;
        _currentIndex = 0;
      }
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          key: const ValueKey("home"),
          auth: widget.auth,
          apiClient: widget.apiClient,
          themeController: widget.themeController,
          languageController: widget.languageController,
          feed: feed,
          onNotificationRefresh: _notificationController.refreshUnreadCount,
        );
      case 1:
        return NotificationsScreen(
          key: const ValueKey("notifications"),
          apiClient: widget.apiClient,
          auth: widget.auth,
        );
      case 2:
        return SearchScreen(
          key: const ValueKey("search"),
          apiClient: widget.apiClient,
          auth: widget.auth,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: _FeedShellDrawer(
        feed: feed,
        auth: widget.auth,
        apiClient: widget.apiClient,
        themeController: widget.themeController,
        languageController: widget.languageController,
        onScopeSelected: _changeFeedScope,
      ),
      body: Stack(
        children: [
          PageTransitionSwitcher(
            duration: const Duration(milliseconds: 280),
            reverse: _currentIndex < _previousIndex,
            transitionBuilder: (child, animation, secondaryAnimation) {
              return SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              );
            },
            child: _buildPage(_currentIndex),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _BottomShellNavBar(
                currentIndex: _currentIndex,
                unreadCount: _notificationController.unreadCount,
                onHomeTap: () => _setPage(0),
                onNotificationsTap: () => _setPage(1),
                onAddRecipeTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateRecipeScreen(apiClient: widget.apiClient),
                    ),
                  );
                  if (result == true) {
                    _notificationController.refreshUnreadCount();
                  }
                },
                onSearchTap: () => _setPage(2),
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomShellNavBar extends StatelessWidget {
  const _BottomShellNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onHomeTap,
    required this.onNotificationsTap,
    required this.onAddRecipeTap,
    required this.onSearchTap,
    required this.onMenuTap,
  });

  final int currentIndex;
  final int unreadCount;
  final VoidCallback onHomeTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAddRecipeTap;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 52,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavAction(
                icon: Icons.home_rounded,
                isActive: currentIndex == 0,
                onTap: onHomeTap,
              ),
              _BottomNavAction(
                icon: Icons.notifications_outlined,
                isActive: currentIndex == 1,
                badgeCount: unreadCount,
                onTap: onNotificationsTap,
              ),
              _BottomNavAction(
                icon: Icons.add_rounded,
                isActive: false,
                onTap: onAddRecipeTap,
              ),
              _BottomNavAction(
                icon: Icons.search_rounded,
                isActive: currentIndex == 2,
                onTap: onSearchTap,
              ),
              _BottomNavAction(
                icon: Icons.menu_rounded,
                isActive: false,
                onTap: onMenuTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavAction extends StatelessWidget {
  const _BottomNavAction({
    required this.icon,
    required this.onTap,
    required this.isActive,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);
    final iconColor = isActive ? activeColor : inactiveColor;

    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 26, color: iconColor),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  badgeCount > 99 ? "99+" : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedShellDrawer extends StatelessWidget {
  const _FeedShellDrawer({
    required this.feed,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.onScopeSelected,
  });

  final FeedController feed;
  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final ValueChanged<String> onScopeSelected;

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
                "Menu",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                feed.scope == "global" ? Icons.check_circle : Icons.circle_outlined,
                color: feed.scope == "global" ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(AppLocalizations.of(context)?.global ?? "Global"),
              subtitle: Text(AppLocalizations.of(context)?.seeRecipesFromEveryone ?? "See recipes from everyone"),
              selected: feed.scope == "global",
              onTap: () {
                Navigator.of(context).pop();
                onScopeSelected("global");
              },
            ),
            ListTile(
              leading: Icon(
                feed.scope == "following" ? Icons.check_circle : Icons.circle_outlined,
                color: feed.scope == "following" ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(AppLocalizations.of(context)?.following ?? "Following"),
              subtitle: Text(AppLocalizations.of(context)?.seeRecipesFromPeopleYouFollow ?? "See recipes from people you follow"),
              selected: feed.scope == "following",
              enabled: auth.isLoggedIn,
              onTap: () {
                if (!auth.isLoggedIn) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)?.logInToSeeFollowingFeed ?? "Log in to see Following feed",
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                onScopeSelected("following");
              },
            ),
            ListTile(
              leading: Icon(
                feed.scope == "popular" ? Icons.check_circle : Icons.circle_outlined,
                color: feed.scope == "popular" ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(AppLocalizations.of(context)?.popular ?? "Popular"),
              subtitle: Text(AppLocalizations.of(context)?.mostPopularRecipes ?? "Most popular recipes"),
              selected: feed.scope == "popular",
              onTap: () {
                Navigator.of(context).pop();
                onScopeSelected("popular");
              },
            ),
            ListTile(
              leading: Icon(
                feed.scope == "trending" ? Icons.check_circle : Icons.circle_outlined,
                color: feed.scope == "trending" ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(AppLocalizations.of(context)?.trending ?? "Trending"),
              subtitle: Text(AppLocalizations.of(context)?.trendingNow ?? "Trending now"),
              selected: feed.scope == "trending",
              onTap: () {
                Navigator.of(context).pop();
                onScopeSelected("trending");
              },
            ),
            const Divider(),
            if (auth.isLoggedIn) ...[
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(AppLocalizations.of(context)?.savedRecipes ?? "Saved Recipes"),
                subtitle: Text(AppLocalizations.of(context)?.viewYourBookmarkedRecipes ?? "View your bookmarked recipes"),
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
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.analytics_rounded),
                title: Text(AppLocalizations.of(context)?.analyticsStatistics ?? "Analytics Statistics"),
                subtitle: Text(AppLocalizations.of(context)?.viewTrackingStatistics ?? "View tracking statistics"),
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
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(AppLocalizations.of(context)?.settings ?? "Settings"),
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
              ),
              ListTile(
                leading: buildUserAvatar(
                  context,
                  auth.me?["avatar_url"]?.toString(),
                  auth.me?["username"]?.toString() ?? "",
                ),
                title: Text(AppLocalizations.of(context)?.profile ?? "Profile"),
                subtitle: Text(
                  auth.me?["username"] != null
                      ? "@${auth.me!["username"]}"
                      : (AppLocalizations.of(context)?.viewProfile ?? "View your profile"),
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
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(AppLocalizations.of(context)?.logout ?? "Logout"),
              onTap: () {
                Navigator.of(context).pop();
                auth.logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
