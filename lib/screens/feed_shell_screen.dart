import "dart:async";

import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../constants/enums.dart";
import "../feed/feed_api.dart";
import "../feed/feed_controller.dart";
import "../feed/feed_view_controller.dart";
import "../recipes/recipe_api.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../notifications/notification_api.dart";
import "../notifications/notification_controller.dart";
import "../services/app_tour_service.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/theme_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "create_recipe_screen.dart";
import "home_screen.dart";
import "notifications_screen.dart";
import "profile_screen.dart";
import "saved_recipes_screen.dart";
import "search_screen.dart";
import "settings_screen.dart";
import "shared_recipes_screen.dart";
import "shared_shopping_lists_screen.dart";
import "shopping_list_screen.dart";

class FeedShellScreen extends StatefulWidget {
  const FeedShellScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.shoppingListController,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final ShoppingListController shoppingListController;

  @override
  State<FeedShellScreen> createState() => _FeedShellScreenState();
}

class _FeedShellScreenState extends State<FeedShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final FeedController feed;
  late final FeedViewController _feedViewController;
  final ScrollController _feedScrollController = ScrollController();
  int _currentIndex = 0;

  late final NotificationController _notificationController;
  Timer? _notificationTimer;

  // Tour keys
  final GlobalKey _feedKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _createKey = GlobalKey();
  final GlobalKey _notificationsKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    feed = FeedController(
      feedApi: FeedApi(widget.apiClient),
      recipeApi: RecipeApi(widget.apiClient),
    );
    _feedViewController = FeedViewController();
    feed.loadInitial();

    final notificationApi = NotificationApi(widget.apiClient);
    _notificationController = NotificationController(notificationApi: notificationApi);
    // Note: We don't add a listener that calls setState here.
    // Instead, we use ListenableBuilder in the widget tree to only rebuild
    // the notification badge, not the entire screen.
    _notificationController.refreshUnreadCount();
    _startNotificationPolling();

    // Check and show tour for first-time users
    _checkAndShowTour();
  }

  Future<void> _checkAndShowTour() async {
    final userId = widget.auth.me?["id"]?.toString();
    if (userId == null || userId.isEmpty) return;
    final tourCompleted = await AppTourService.hasTourCompleted(userId);
    if (!tourCompleted && mounted) {
      // Delay to ensure widgets are built
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          AppTourService.showTour(
            context,
            userId: userId,
            feedKey: _feedKey,
            searchKey: _searchKey,
            createKey: _createKey,
            notificationsKey: _notificationsKey,
            menuKey: _menuKey,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    feed.dispose();
    _feedViewController.dispose();
    _feedScrollController.dispose();
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
      _currentIndex = index;
    });
  }

  void _onHomeTap() {
    if (_currentIndex == 0) {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      _setPage(0);
    }
  }

  void _ensureHomeTab() {
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
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
        shoppingListController: widget.shoppingListController,
        feedViewController: _feedViewController,
        onNavigateToFeed: _ensureHomeTab,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            auth: widget.auth,
            apiClient: widget.apiClient,
            themeController: widget.themeController,
            languageController: widget.languageController,
            feed: feed,
            feedViewController: _feedViewController,
            scrollController: _feedScrollController,
            onNotificationRefresh: _notificationController.refreshUnreadCount,
            shoppingListController: widget.shoppingListController,
          ),
          NotificationsScreen(
            apiClient: widget.apiClient,
            auth: widget.auth,
            notificationController: _notificationController,
            shoppingListController: widget.shoppingListController,
          ),
          SearchScreen(
            apiClient: widget.apiClient,
            auth: widget.auth,
            shoppingListController: widget.shoppingListController,
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _notificationController,
        builder: (context, _) {
          return _BottomShellNavBar(
            currentIndex: _currentIndex,
            unreadCount: _notificationController.unreadCount,
            onHomeTap: _onHomeTap,
            onNotificationsTap: () => _setPage(1),
            onAddRecipeTap: () async {
              if (widget.auth.isSoftBanned || widget.auth.isPermanentlyBanned) {
                final localizations = AppLocalizations.of(context);
                final bannedUntil = widget.auth.softBannedUntil;
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(bannedUntil != null
                        ? (localizations?.accountSoftBanned ?? "Account Temporarily Suspended")
                        : (localizations?.accountPermanentlyBanned ?? "Account Permanently Suspended")),
                    content: Text(bannedUntil != null
                        ? (localizations?.accountSoftBannedUntil(formatDate(context, bannedUntil)) ?? "Your account is suspended.")
                        : (localizations?.accountPermanentlyBannedMessage ?? "Your account has been permanently suspended.")),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(localizations?.ok ?? "OK"),
                      ),
                    ],
                  ),
                );
                return;
              }
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
            feedKey: _feedKey,
            searchKey: _searchKey,
            createKey: _createKey,
            notificationsKey: _notificationsKey,
            menuKey: _menuKey,
          );
        },
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
    required this.feedKey,
    required this.searchKey,
    required this.createKey,
    required this.notificationsKey,
    required this.menuKey,
  });

  final int currentIndex;
  final int unreadCount;
  final VoidCallback onHomeTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAddRecipeTap;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final GlobalKey feedKey;
  final GlobalKey searchKey;
  final GlobalKey createKey;
  final GlobalKey notificationsKey;
  final GlobalKey menuKey;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    final localizations = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavAction(
                key: feedKey,
                icon: Icons.home_rounded,
                label: localizations?.home ?? "Home",
                isActive: currentIndex == 0,
                onTap: onHomeTap,
              ),
              _BottomNavAction(
                key: notificationsKey,
                icon: Icons.notifications_outlined,
                label: localizations?.notifications ?? "Notifications",
                isActive: currentIndex == 1,
                badgeCount: unreadCount,
                onTap: onNotificationsTap,
              ),
              _BottomNavAction(
                key: createKey,
                icon: Icons.add_rounded,
                label: localizations?.add ?? "Add",
                isActive: false,
                onTap: onAddRecipeTap,
              ),
              _BottomNavAction(
                key: searchKey,
                icon: Icons.search_rounded,
                label: localizations?.search ?? "Search",
                isActive: currentIndex == 2,
                onTap: onSearchTap,
              ),
              _BottomNavAction(
                key: menuKey,
                icon: Icons.menu_rounded,
                label: localizations?.menu ?? "Menu",
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
    super.key,
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
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    right: isActive ? 8 : 4,
                    top: 2,
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

class _FeedShellDrawer extends StatefulWidget {
  const _FeedShellDrawer({
    required this.feed,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.shoppingListController,
    required this.feedViewController,
    required this.onNavigateToFeed,
  });

  final FeedController feed;
  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final ShoppingListController shoppingListController;
  final FeedViewController feedViewController;
  final VoidCallback onNavigateToFeed;

  @override
  State<_FeedShellDrawer> createState() => _FeedShellDrawerState();
}

class _FeedShellDrawerState extends State<_FeedShellDrawer> {
  FeedScope? _expandedScope;

  @override
  void initState() {
    super.initState();
    _expandedScope = widget.feed.scope;
  }

  void _toggleExpand(FeedScope scope) {
    setState(() {
      _expandedScope = _expandedScope == scope ? null : scope;
    });
  }

  void _selectOption({
    required FeedScope scope,
    FeedSort? sort,
    PopularPeriod? popularPeriod,
    int? trendingDays,
  }) {
    widget.feed.setScopeAndOptions(
      newScope: scope,
      newSort: sort,
      newPopularPeriod: popularPeriod,
      newTrendingDays: trendingDays,
    );
    Navigator.of(context).pop();
    widget.onNavigateToFeed();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.feed,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Profile section
                if (widget.auth.isLoggedIn) ...[
                  _DrawerCard(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            auth: widget.auth,
                            apiClient: widget.apiClient,
                            shoppingListController: widget.shoppingListController,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        buildUserAvatar(
                          context,
                          widget.auth.me?["avatar_url"]?.toString(),
                          widget.auth.me?["username"]?.toString() ?? "",
                          radius: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "@${widget.auth.me?["username"] ?? ""}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                localizations?.viewProfile ?? "View your profile",
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
                _SectionHeader(title: localizations?.feedPreferences ?? "FEED PREFERENCES"),
                const SizedBox(height: 8),

                // Global
                _buildExpandableScope(
                  scope: FeedScope.global,
                  icon: Icons.public_rounded,
                  title: localizations?.global ?? "Global",
                  subtitle: localizations?.seeRecipesFromEveryone ?? "See recipes from everyone",
                  subItems: [
                    _SubItem(
                      label: localizations?.recent ?? "Recent",
                      isActive: widget.feed.scope == FeedScope.global && widget.feed.sort == FeedSort.recent,
                      onTap: () => _selectOption(scope: FeedScope.global, sort: FeedSort.recent),
                    ),
                    _SubItem(
                      label: localizations?.top ?? "Top",
                      isActive: widget.feed.scope == FeedScope.global && widget.feed.sort == FeedSort.top,
                      onTap: () => _selectOption(scope: FeedScope.global, sort: FeedSort.top),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Following
                _buildExpandableScope(
                  scope: FeedScope.following,
                  icon: Icons.people_alt_outlined,
                  title: localizations?.following ?? "Following",
                  subtitle: localizations?.seeRecipesFromPeopleYouFollow ?? "See recipes from people you follow",
                  enabled: widget.auth.isLoggedIn,
                  onDisabledTap: () {
                    Navigator.of(context).pop();
                    ErrorUtils.showInfo(
                      context,
                      localizations?.logInToSeeFollowingFeed ?? "Log in to see Following feed",
                    );
                  },
                  subItems: [
                    _SubItem(
                      label: localizations?.recent ?? "Recent",
                      isActive: widget.feed.scope == FeedScope.following && widget.feed.sort == FeedSort.recent,
                      onTap: () => _selectOption(scope: FeedScope.following, sort: FeedSort.recent),
                    ),
                    _SubItem(
                      label: localizations?.top ?? "Top",
                      isActive: widget.feed.scope == FeedScope.following && widget.feed.sort == FeedSort.top,
                      onTap: () => _selectOption(scope: FeedScope.following, sort: FeedSort.top),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Popular
                _buildExpandableScope(
                  scope: FeedScope.popular,
                  icon: Icons.local_fire_department_outlined,
                  title: localizations?.popular ?? "Popular",
                  subtitle: localizations?.mostPopularRecipes ?? "Most popular recipes",
                  subItems: [
                    _SubItem(
                      label: localizations?.allTime ?? "All Time",
                      isActive: widget.feed.scope == FeedScope.popular && widget.feed.popularPeriod == PopularPeriod.allTime,
                      onTap: () => _selectOption(scope: FeedScope.popular, popularPeriod: PopularPeriod.allTime),
                    ),
                    _SubItem(
                      label: localizations?.last30Days ?? "Last 30 Days",
                      isActive: widget.feed.scope == FeedScope.popular && widget.feed.popularPeriod == PopularPeriod.last30Days,
                      onTap: () => _selectOption(scope: FeedScope.popular, popularPeriod: PopularPeriod.last30Days),
                    ),
                    _SubItem(
                      label: localizations?.last7Days ?? "Last 7 Days",
                      isActive: widget.feed.scope == FeedScope.popular && widget.feed.popularPeriod == PopularPeriod.last7Days,
                      onTap: () => _selectOption(scope: FeedScope.popular, popularPeriod: PopularPeriod.last7Days),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Trending
                _buildExpandableScope(
                  scope: FeedScope.trending,
                  icon: Icons.trending_up_rounded,
                  title: localizations?.trending ?? "Trending",
                  subtitle: localizations?.trendingNow ?? "Trending now",
                  subItems: [
                    _SubItem(
                      label: localizations?.last7Days ?? "Last 7 Days",
                      isActive: widget.feed.scope == FeedScope.trending && widget.feed.trendingDays == 7,
                      onTap: () => _selectOption(scope: FeedScope.trending, trendingDays: 7),
                    ),
                    _SubItem(
                      label: localizations?.last30Days ?? "Last 30 Days",
                      isActive: widget.feed.scope == FeedScope.trending && widget.feed.trendingDays == 30,
                      onTap: () => _selectOption(scope: FeedScope.trending, trendingDays: 30),
                    ),
                  ],
                ),

                // Quick Access section
                if (widget.auth.isLoggedIn) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(title: localizations?.quickAccess ?? "QUICK ACCESS"),
                  const SizedBox(height: 8),
                  _QuickAccessCard(
                    icon: Icons.bookmark_outline_rounded,
                    title: localizations?.savedRecipes ?? "Saved Recipes",
                    subtitle: localizations?.viewYourBookmarkedRecipes ?? "View your bookmarked recipes",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SavedRecipesScreen(
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                            shoppingListController: widget.shoppingListController,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickAccessCard(
                    icon: Icons.shopping_cart_outlined,
                    title: localizations?.shoppingList ?? "Shopping List",
                    subtitle: localizations?.manageYourShoppingList ?? "Manage your shopping list",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShoppingListScreen(
                            controller: widget.shoppingListController,
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickAccessCard(
                    icon: Icons.folder_shared,
                    title: localizations?.sharedRecipes ?? "Shared Recipes",
                    subtitle: localizations?.recipesSharedWithYou ?? "Recipes shared with you",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SharedRecipesScreen(
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                            shoppingListController: widget.shoppingListController,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickAccessCard(
                    icon: Icons.shopping_basket_outlined,
                    title: localizations?.sharedShoppingLists ?? "Shared Shopping Lists",
                    subtitle: localizations?.listsSharedWithYou ?? "Shopping lists shared with you",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SharedShoppingListsScreen(
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickAccessCard(
                    icon: Icons.settings_outlined,
                    title: localizations?.settings ?? "Settings",
                    subtitle: localizations?.appPreferences ?? "App preferences",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            themeController: widget.themeController,
                            languageController: widget.languageController,
                            feedViewController: widget.feedViewController,
                            auth: widget.auth,
                            apiClient: widget.apiClient,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandableScope({
    required FeedScope scope,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<_SubItem> subItems,
    bool enabled = true,
    VoidCallback? onDisabledTap,
  }) {
    final isSelected = widget.feed.scope == scope;
    final isExpanded = _expandedScope == scope;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExpandableFeedOptionCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
          isExpanded: isExpanded,
          enabled: enabled,
          onTap: () {
            if (!enabled) {
              onDisabledTap?.call();
              return;
            }
            _toggleExpand(scope);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: subItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SubOptionCard(
                        label: item.label,
                        isActive: item.isActive,
                        onTap: item.onTap,
                      ),
                    )).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SubItem {
  const _SubItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
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
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_DrawerCard> createState() => _DrawerCardState();
}

class _DrawerCardState extends State<_DrawerCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final hoverColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    final pressedColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);

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

class _ExpandableFeedOptionCard extends StatefulWidget {
  const _ExpandableFeedOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_ExpandableFeedOptionCard> createState() => _ExpandableFeedOptionCardState();
}

class _ExpandableFeedOptionCardState extends State<_ExpandableFeedOptionCard> {
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
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: widget.isExpanded ? 0.5 : 0.0,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: widget.isSelected
                      ? primaryColor
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

class _SubOptionCard extends StatefulWidget {
  const _SubOptionCard({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SubOptionCard> createState() => _SubOptionCardState();
}

class _SubOptionCardState extends State<_SubOptionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final baseColor = widget.isActive
        ? primaryColor.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final pressedColor = primaryColor.withValues(alpha: 0.15);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed ? pressedColor : baseColor,
          borderRadius: BorderRadius.circular(10),
          border: widget.isActive
              ? Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              widget.isActive ? Icons.check_rounded : Icons.arrow_right_rounded,
              size: 18,
              color: widget.isActive
                  ? primaryColor
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                color: widget.isActive
                    ? primaryColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
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
