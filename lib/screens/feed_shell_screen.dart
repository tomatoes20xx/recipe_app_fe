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
    // Note: We don't add a listener that calls setState here.
    // Instead, we use ListenableBuilder in the widget tree to only rebuild
    // the notification badge, not the entire screen.
    _notificationController.refreshUnreadCount();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    feed.dispose();
    _notificationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
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
              // Use ListenableBuilder to only rebuild the nav bar when notification count changes,
              // not the entire FeedShellScreen. This prevents expensive rebuilds of all pages.
              child: ListenableBuilder(
                listenable: _notificationController,
                builder: (context, _) {
                  return _BottomShellNavBar(
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
                  );
                },
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
                label: "Home",
                isActive: currentIndex == 0,
                onTap: onHomeTap,
              ),
              _BottomNavAction(
                icon: Icons.notifications_outlined,
                label: "Notifications",
                isActive: currentIndex == 1,
                badgeCount: unreadCount,
                onTap: onNotificationsTap,
              ),
              _BottomNavAction(
                icon: Icons.add_rounded,
                label: "Add",
                isActive: false,
                onTap: onAddRecipeTap,
              ),
              _BottomNavAction(
                icon: Icons.search_rounded,
                label: "Search",
                isActive: currentIndex == 2,
                onTap: onSearchTap,
              ),
              _BottomNavAction(
                icon: Icons.menu_rounded,
                label: "Menu",
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
    required this.label,
    required this.onTap,
    required this.isActive,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);
    final iconColor = isActive ? activeColor : inactiveColor;

    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);

    return Expanded(
      flex: isActive ? 2 : 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return InkResponse(
            onTap: onTap,
            radius: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isActive ? constraints.maxWidth : constraints.maxWidth,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: isActive ? Border.all(color: borderColor, width: 1) : null,
                      ),
                      child: IntrinsicWidth(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 26, color: iconColor),
                            if (isActive) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: iconColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
        },
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Profile section
            if (auth.isLoggedIn) ...[
              _DrawerCard(
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
                child: Row(
                  children: [
                    buildUserAvatar(
                      context,
                      auth.me?["avatar_url"]?.toString(),
                      auth.me?["username"]?.toString() ?? "",
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "@${auth.me?["username"] ?? ""}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context)?.viewProfile ?? "View your profile",
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Feed Preferences section
            _SectionHeader(title: AppLocalizations.of(context)?.feedPreferences ?? "FEED PREFERENCES"),
            const SizedBox(height: 8),
            _FeedOptionCard(
              icon: Icons.public_rounded,
              title: AppLocalizations.of(context)?.global ?? "Global",
              subtitle: AppLocalizations.of(context)?.seeRecipesFromEveryone ?? "See recipes from everyone",
              isSelected: feed.scope == "global",
              onTap: () {
                Navigator.of(context).pop();
                onScopeSelected("global");
              },
            ),
            const SizedBox(height: 8),
            _FeedOptionCard(
              icon: Icons.people_alt_outlined,
              title: AppLocalizations.of(context)?.following ?? "Following",
              subtitle: AppLocalizations.of(context)?.seeRecipesFromPeopleYouFollow ?? "See recipes from people you follow",
              isSelected: feed.scope == "following",
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
            const SizedBox(height: 8),
            _FeedOptionCard(
              icon: Icons.local_fire_department_outlined,
              title: AppLocalizations.of(context)?.popular ?? "Popular",
              subtitle: AppLocalizations.of(context)?.mostPopularRecipes ?? "Most popular recipes",
              isSelected: feed.scope == "popular",
              onTap: () {
                Navigator.of(context).pop();
                onScopeSelected("popular");
              },
            ),
            const SizedBox(height: 8),
            _FeedOptionCard(
              icon: Icons.trending_up_rounded,
              title: AppLocalizations.of(context)?.trending ?? "Trending",
              subtitle: AppLocalizations.of(context)?.trendingNow ?? "Trending now",
              isSelected: feed.scope == "trending",
              onTap: () {
                Navigator.of(context).pop();
                onScopeSelected("trending");
              },
            ),

            // Quick Access section
            if (auth.isLoggedIn) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: AppLocalizations.of(context)?.quickAccess ?? "QUICK ACCESS"),
              const SizedBox(height: 8),
              _QuickAccessCard(
                icon: Icons.bookmark_outline_rounded,
                title: AppLocalizations.of(context)?.savedRecipes ?? "Saved Recipes",
                subtitle: AppLocalizations.of(context)?.viewYourBookmarkedRecipes ?? "View your bookmarked recipes",
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
              const SizedBox(height: 8),
              _QuickAccessCard(
                icon: Icons.bar_chart_rounded,
                title: AppLocalizations.of(context)?.analyticsStatistics ?? "Analytics Statistics",
                subtitle: AppLocalizations.of(context)?.viewTrackingStatistics ?? "View tracking statistics",
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
              const SizedBox(height: 8),
              _QuickAccessCard(
                icon: Icons.settings_outlined,
                title: AppLocalizations.of(context)?.settings ?? "Settings",
                subtitle: AppLocalizations.of(context)?.appPreferences ?? "App preferences",
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
            ],

            // Logout button
            const SizedBox(height: 24),
            _DrawerCard(
              isDestructive: true,
              onTap: () {
                Navigator.of(context).pop();
                auth.logout();
              },
              child: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)?.logout ?? "Logout",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.error,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DrawerCard extends StatefulWidget {
  const _DrawerCard({
    required this.child,
    required this.onTap,
    this.isDestructive = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  State<_DrawerCard> createState() => _DrawerCardState();
}

class _DrawerCardState extends State<_DrawerCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final hoverColor = widget.isDestructive
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    final pressedColor = widget.isDestructive
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isPressed ? pressedColor : (_isHovered ? hoverColor : baseColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _FeedOptionCard extends StatefulWidget {
  const _FeedOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_FeedOptionCard> createState() => _FeedOptionCardState();
}

class _FeedOptionCardState extends State<_FeedOptionCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final disabledAlpha = widget.enabled ? 1.0 : 0.5;
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final hoverColor = primaryColor.withValues(alpha: 0.1);
    final pressedColor = primaryColor.withValues(alpha: 0.15);
    final selectedColor = primaryColor.withValues(alpha: 0.12);

    Color bgColor;
    if (widget.isSelected) {
      bgColor = selectedColor;
    } else if (_isPressed) {
      bgColor = pressedColor;
    } else if (_isHovered) {
      bgColor = hoverColor;
    } else {
      bgColor = baseColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.isSelected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: widget.isSelected
                      ? primaryColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7 * disabledAlpha),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: widget.isSelected
                            ? primaryColor
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: disabledAlpha),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5 * disabledAlpha),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  widget.isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  key: ValueKey(widget.isSelected),
                  size: 22,
                  color: widget.isSelected
                      ? primaryColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatefulWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final hoverColor = primaryColor.withValues(alpha: 0.08);
    final pressedColor = primaryColor.withValues(alpha: 0.12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isPressed ? pressedColor : (_isHovered ? hoverColor : baseColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isHovered || _isPressed
                      ? primaryColor.withValues(alpha: 0.25)
                      : primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                duration: const Duration(milliseconds: 150),
                offset: _isHovered ? const Offset(0.1, 0) : Offset.zero,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: _isHovered
                      ? primaryColor.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
