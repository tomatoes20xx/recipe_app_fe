import "dart:async";

import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
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
import "../services/notification_service.dart";
import "../services/push_prompt_service.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/theme_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "create_recipe_screen.dart";
import "email_verification_screen.dart";
import "home_screen.dart";
import "notifications_screen.dart";
import "profile_screen.dart";
import "saved_recipes_screen.dart";
import "search_screen.dart";
import "settings_screen.dart";
import "shared_recipes_screen.dart";
import "shared_shopping_lists_screen.dart";
import "shopping_list_screen.dart";
import "../recipes/recipe_detail_screen.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "help_and_support_screen.dart";

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

class _FeedShellScreenState extends State<FeedShellScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final FeedController feed;
  late final FeedViewController _feedViewController;
  final ScrollController _feedScrollController = ScrollController();
  int _currentIndex = 0;
  late final NotificationController _notificationController;
  late final NotificationApi _notificationApi;
  StreamSubscription<String>? _fcmTokenRefreshSub;

  // Tour keys
  final GlobalKey _feedKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _createKey = GlobalKey();
  final GlobalKey _notificationsKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    feed = FeedController(
      feedApi: FeedApi(widget.apiClient),
      recipeApi: RecipeApi(widget.apiClient),
    );
    _feedViewController = FeedViewController();
    _flushPendingSeenIds().then((_) => feed.loadInitial());

    _notificationApi = NotificationApi(widget.apiClient);
    _notificationController = NotificationController(notificationApi: _notificationApi);
    // Note: We don't add a listener that calls setState here.
    // Instead, we use ListenableBuilder in the widget tree to only rebuild
    // the notification badge, not the entire screen.
    _notificationController.refreshUnreadCount();
    _registerFcmToken();
    NotificationService().onNotificationTap = _navigateFromNotification;
    final pendingTap = NotificationService().pendingTap;
    if (pendingTap != null) {
      NotificationService().clearPendingTap();
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateFromNotification(pendingTap));
    }
    NotificationService().onBadgeCountUpdate = (count) {
      if (count > _notificationController.unreadCount) {
        // New notification arrived — silently prepend it so it's ready when user taps
        _notificationController.silentRefresh();
      } else {
        _notificationController.setUnreadCount(count);
      }
    };

    // Check and show tour for first-time users
    _checkAndShowTour();
  }

  Future<void> _flushPendingSeenIds() async {
    if (!widget.auth.isLoggedIn) return;
    final ids = await FeedController.popPendingSeenIds();
    if (ids.isEmpty) return;
    try {
      await FeedApi(widget.apiClient).postSeenRecipes(ids);
    } catch (_) {
      debugPrint('[DISCOVERY] flush failed, re-persisting ${ids.length} ids');
      await FeedController.savePendingSeenIds(ids);
    }
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

  /// Returns true if the user is allowed to perform a write action.
  /// Shows a bottom sheet gate if email is not verified.
  Future<bool> _checkEmailVerified() async {
    // me not loaded yet (slow network at startup) — fetch it now.
    if (widget.auth.me == null && widget.auth.isLoggedIn) {
      await widget.auth.refreshMe();
    }
    if (widget.auth.me == null || widget.auth.emailVerified) return true;

    final email = widget.auth.me?['email']?.toString() ?? '';
    bool openVerification = false;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('📧', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                l?.emailGateTitle ?? 'Verify your email first',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l?.emailGateMessage(email) ?? 'To continue, please verify your email address ($email).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    openVerification = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(l?.emailGateButton ?? 'Verify email'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l?.attPermissionSkip ?? 'Not now'),
              ),
            ],
          ),
        );
      },
    );
    if (openVerification) {
      await _openVerificationScreen(codeSent: widget.auth.verificationEmailSent);
    }
    return false;
  }

  Future<void> _openVerificationScreen({bool codeSent = false}) async {
    final navigator = Navigator.of(context);
    final verified = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          auth: widget.auth,
          email: widget.auth.me?['email'] ?? '',
          codeSent: codeSent,
        ),
      ),
    );
    if (verified == true) {
      await widget.auth.refreshMe();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feed.dispose();
    _feedViewController.dispose();
    _feedScrollController.dispose();
    _notificationController.dispose();
    NotificationService().onBadgeCountUpdate = null;
    _fcmTokenRefreshSub?.cancel();
    widget.auth.onBeforeLogout = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      PushPromptService().onForegrounded(context, widget.auth, widget.apiClient);
      if (widget.auth.isLoggedIn) {
        _notificationController.refreshUnreadCount();
      }
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (widget.auth.isLoggedIn) {
        final ids = feed.flushSeenIds();
        if (ids.isNotEmpty) {
          FeedApi(widget.apiClient).postSeenRecipes(ids.toList()).catchError((_) {});
        }
      }
    }
  }

  void _registerFcmToken() {
    final platform = Platform.isAndroid ? 'android' : 'ios';
    final token = NotificationService().fcmToken;
    if (token != null) {
      _notificationApi.registerFcmToken(token, platform).catchError((_) {});
    }
    _fcmTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) => _notificationApi.registerFcmToken(newToken, platform).catchError((_) {}),
    );
    widget.auth.onBeforeLogout = () async {
      final fcmToken = NotificationService().fcmToken;
      if (fcmToken != null) {
        await _notificationApi.removeFcmToken(fcmToken).catchError((_) {});
      }
    };
  }

  void _navigateFromNotification(Map<String, String?> data) {
    final type = data['type'];
    final recipeId = data['recipe_id'];
    final actorUsername = data['actor_username'];

    switch (type) {
      case 'like':
      case 'recipe':
      case 'bookmark':
      case 'recipe_share':
        if (recipeId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(
              recipeId: recipeId,
              apiClient: widget.apiClient,
              auth: widget.auth,
              shoppingListController: widget.shoppingListController,
            ),
          ));
        }
        break;
      case 'comment':
        if (recipeId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(
              recipeId: recipeId,
              apiClient: widget.apiClient,
              auth: widget.auth,
              shoppingListController: widget.shoppingListController,
              openComments: true,
            ),
          ));
        }
        break;
      case 'follow':
        if (actorUsername != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProfileScreen(
              auth: widget.auth,
              apiClient: widget.apiClient,
              shoppingListController: widget.shoppingListController,
              username: actorUsername,
            ),
          ));
        }
        break;
      case 'shopping_list_share':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SharedShoppingListsScreen(
            apiClient: widget.apiClient,
            auth: widget.auth,
            shoppingListController: widget.shoppingListController,
          ),
        ));
        break;
    }
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
            onNotificationsTap: () {
                _setPage(1);
                _notificationController.silentRefresh();
              },
            onAddRecipeTap: () async {
              if (!await _checkEmailVerified()) return;
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
  UserProfile? _drawerProfile;
  LibraryCounts? _libraryCounts;

  @override
  void initState() {
    super.initState();
    _expandedScope = widget.feed.scope;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!widget.auth.isLoggedIn) return;
    final username = widget.auth.me?["username"]?.toString();
    if (username == null || username.isEmpty) return;
    final userApi = UserApi(widget.apiClient);
    try {
      final results = await Future.wait([
        userApi.getUserProfile(username),
        userApi.getLibraryCounts(),
      ]);
      if (mounted) {
        setState(() {
          _drawerProfile = results[0] as UserProfile;
          _libraryCounts = results[1] as LibraryCounts;
        });
      }
    } catch (_) {}
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

  void _confirmSignOut(BuildContext context, AppLocalizations? localizations) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations?.signOutConfirmTitle ?? "Sign out?"),
        content: Text(localizations?.signOutConfirmMessage ?? "Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              widget.auth.logout();
            },
            child: Text(
              localizations?.signOut ?? "Sign out",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppLocalizations? localizations) {
    const primaryColor = Color(0xFF53B175);
    final me = widget.auth.me;
    final username = me?["username"]?.toString() ?? "";
    final displayName = me?["display_name"]?.toString() ?? username;
    final avatarUrl = me?["avatar_url"]?.toString();
    final profile = _drawerProfile;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: primaryColor,
        child: Stack(
          children: [
            Positioned(
              top: -35,
              right: -35,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 25,
              right: 55,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -45,
              left: -25,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                auth: widget.auth,
                                apiClient: widget.apiClient,
                                shoppingListController: widget.shoppingListController,
                              ),
                            ));
                          },
                          child: buildUserAvatar(context, avatarUrl, username, radius: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                auth: widget.auth,
                                apiClient: widget.apiClient,
                                shoppingListController: widget.shoppingListController,
                              ),
                            ));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "@$username",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              themeController: widget.themeController,
                              languageController: widget.languageController,
                              feedViewController: widget.feedViewController,
                              auth: widget.auth,
                              apiClient: widget.apiClient,
                            ),
                          ));
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileStat(
                          value: profile?.recipesCount.toString() ?? "",
                          label: localizations?.recipes ?? "Recipes",
                          loading: profile == null,
                        ),
                      ),
                      Expanded(
                        child: _ProfileStat(
                          value: profile?.followersCount.toString() ?? "",
                          label: localizations?.followers ?? "Followers",
                          loading: profile == null,
                        ),
                      ),
                      Expanded(
                        child: _ProfileStat(
                          value: profile?.followingCount.toString() ?? "",
                          label: localizations?.followingTitle ?? "Following",
                          loading: profile == null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryGrid(BuildContext context, AppLocalizations? localizations) {
    final counts = _libraryCounts;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _LibraryGridCard(
                icon: Icons.bookmark_outline_rounded,
                title: localizations?.savedRecipes ?? "Saved Recipes",
                loading: counts == null,
                subtitle: counts != null
                    ? localizations?.nSaved(counts.savedRecipes) ?? "${counts.savedRecipes} saved"
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SavedRecipesScreen(
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                    ),
                  ));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.shoppingListController,
                builder: (context, _) {
                  final count = widget.shoppingListController.totalCount;
                  return _LibraryGridCard(
                    icon: Icons.shopping_cart_outlined,
                    title: localizations?.shoppingList ?? "Shopping List",
                    subtitle: "$count ${localizations?.items ?? "items"}",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ShoppingListScreen(
                          controller: widget.shoppingListController,
                          apiClient: widget.apiClient,
                          auth: widget.auth,
                        ),
                      ));
                    },
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _LibraryGridCard(
                icon: Icons.folder_shared_outlined,
                title: localizations?.sharedRecipes ?? "Shared Recipes",
                loading: counts == null,
                subtitle: counts != null
                    ? localizations?.nSaved(counts.sharedRecipes) ?? "${counts.sharedRecipes} saved"
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SharedRecipesScreen(
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                    ),
                  ));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LibraryGridCard(
                icon: Icons.shopping_basket_outlined,
                title: localizations?.sharedShoppingLists ?? "Shared Shopping Lists",
                loading: counts == null,
                subtitle: counts != null
                    ? "${counts.sharedShoppingLists} ${localizations?.items ?? "items"}"
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SharedShoppingListsScreen(
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                    ),
                  ));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.feed, widget.auth]),
          builder: (context, _) {
            return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: <Widget>[
                      if (widget.auth.isLoggedIn) ...[
                        _buildProfileHeader(context, localizations),
                        const SizedBox(height: 24),
                      ],
                      _SectionHeader(title: localizations?.feed ?? "FEED"),
                      const SizedBox(height: 8),
                      _buildExpandableScope(
                        scope: FeedScope.global,
                        icon: Icons.public_rounded,
                        title: localizations?.global ?? "Global",
                        subItems: [
                          _SubItem(
                            label: localizations?.feedSortDiscovery ?? "Discovery",
                            isActive: widget.feed.scope == FeedScope.global && widget.feed.sort == FeedSort.discovery,
                            onTap: () => _selectOption(scope: FeedScope.global, sort: FeedSort.discovery),
                          ),
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
                      _buildExpandableScope(
                        scope: FeedScope.following,
                        icon: Icons.people_alt_outlined,
                        title: localizations?.following ?? "Following",
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
                      _buildExpandableScope(
                        scope: FeedScope.popular,
                        icon: Icons.local_fire_department_outlined,
                        title: localizations?.popular ?? "Popular",
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
                      _buildExpandableScope(
                        scope: FeedScope.trending,
                        icon: Icons.trending_up_rounded,
                        title: localizations?.trending ?? "Trending",
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
                      if (widget.auth.isLoggedIn) ...[
                        const SizedBox(height: 24),
                        _SectionHeader(title: localizations?.library ?? "LIBRARY"),
                        const SizedBox(height: 8),
                        _buildLibraryGrid(context, localizations),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _BottomDrawerButton(
                              icon: Icons.help_outline_rounded,
                              label: localizations?.help ?? "Help",
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const HelpAndSupportScreen(),
                                ));
                              },
                            ),
                          ),
                          if (widget.auth.isLoggedIn) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BottomDrawerButton(
                                icon: Icons.logout_rounded,
                                label: localizations?.signOut ?? "Sign out",
                                isDestructive: true,
                                onTap: () => _confirmSignOut(context, localizations),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
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
    required List<_SubItem> subItems,
    bool enabled = true,
    VoidCallback? onDisabledTap,
  }) {
    final isSelected = widget.feed.scope == scope;
    final isExpanded = _expandedScope == scope;
    final localizations = AppLocalizations.of(context);

    if (isSelected) {
      return _SelectedFeedCard(
        icon: icon,
        title: title,
        nowViewingLabel: localizations?.nowViewing ?? "NOW VIEWING",
        subItems: subItems,
      );
    }

    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (!enabled) {
              onDisabledTap?.call();
              return;
            }
            _toggleExpand(scope);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: onSurface.withValues(alpha: enabled ? 0.65 : 0.3),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: onSurface.withValues(alpha: enabled ? 1.0 : 0.4),
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.25 : 0.0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subItems
                          .map((item) => _FeedPillChip(
                                label: item.label,
                                isActive: item.isActive,
                                onTap: item.onTap,
                              ))
                          .toList(),
                    ),
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


class _SelectedFeedCard extends StatelessWidget {
  const _SelectedFeedCard({
    required this.icon,
    required this.title,
    required this.nowViewingLabel,
    required this.subItems,
  });

  final IconData icon;
  final String title;
  final String nowViewingLabel;
  final List<_SubItem> subItems;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nowViewingLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: subItems
                .map((item) => _FeedPillChip(
                      label: item.label,
                      isActive: item.isActive,
                      onTap: item.onTap,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeedPillChip extends StatefulWidget {
  const _FeedPillChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FeedPillChip> createState() => _FeedPillChipState();
}

class _FeedPillChipState extends State<_FeedPillChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: widget.isActive
              ? primaryColor.withValues(alpha: _isPressed ? 0.85 : 1.0)
              : _isPressed
                  ? onSurface.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isActive ? primaryColor : onSurface.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
            color: widget.isActive ? Colors.white : onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _LibraryGridCard extends StatefulWidget {
  const _LibraryGridCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_LibraryGridCard> createState() => _LibraryGridCardState();
}

class _LibraryGridCardState extends State<_LibraryGridCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final pressedColor = primaryColor.withValues(alpha: 0.12);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isPressed ? pressedColor : baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 20, color: primaryColor),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.loading) ...[
              const SizedBox(height: 4),
              const _SkeletonPill(width: 48, height: 16),
            ] else if (widget.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomDrawerButton extends StatefulWidget {
  const _BottomDrawerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  State<_BottomDrawerButton> createState() => _BottomDrawerButtonState();
}

class _BottomDrawerButtonState extends State<_BottomDrawerButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final pressedColor = widget.isDestructive
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _isPressed ? pressedColor : baseColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label, this.loading = false});

  final String value;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        loading
            ? const _SkeletonPill(width: 32, height: 19, color: Colors.white)
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonPill extends StatefulWidget {
  const _SkeletonPill({this.width = 40, this.height = 10, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  State<_SkeletonPill> createState() => _SkeletonPillState();
}

class _SkeletonPillState extends State<_SkeletonPill> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: _opacity.value),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
