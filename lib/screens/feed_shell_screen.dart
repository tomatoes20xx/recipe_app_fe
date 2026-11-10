import "dart:async";

import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/material.dart";
import "package:flutter_timezone/flutter_timezone.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
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
import "../theme/app_tokens.dart";
import "../theme/status_bar.dart";
import "../theme/theme_controller.dart";
import "../users/streak_controller.dart";
import "../users/user_api.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/profile_avatar.dart";
import "create_recipe_screen.dart";
import "shell_navigation.dart";
import "home_screen.dart";
import "notifications_screen.dart";
import "profile_screen.dart";
import "profile_tab_screen.dart";
import "search_screen.dart";
import "shared_shopping_lists_screen.dart";
import "../recipes/recipe_detail_screen.dart";

// IndexedStack pages, in bottom-nav order. Add opens a screen, not a page.
const _homePage = 0;
const _searchPage = 1;
const _notificationsPage = 2;
const _profilePage = 3;

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
  late final FeedController feed;
  late final FeedViewController _feedViewController;
  final ScrollController _feedScrollController = ScrollController();
  int _currentIndex = _homePage;
  late final NotificationController _notificationController;
  late final NotificationApi _notificationApi;

  /// Shared by the Home streak chip and the Profile tab's streak card.
  late final StreakController _streakController;

  /// The timezone the server last accepted for this account (null until
  /// sent, and again after sign-out).
  String? _syncedTimezone;
  StreamSubscription<String>? _fcmTokenRefreshSub;

  /// Auth state the shell last reacted to (see [_onAuthChanged]).
  late bool _wasSignedIn;

  // Tour keys
  final GlobalKey _feedKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _createKey = GlobalKey();
  final GlobalKey _notificationsKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey(); // the Profile tab item

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    feed = FeedController(
      feedApi: FeedApi(widget.apiClient),
      recipeApi: RecipeApi(widget.apiClient),
      isSignedIn: () => widget.auth.isLoggedIn,
    );
    _feedViewController = FeedViewController();
    _flushPendingSeenIds().then((_) => feed.loadInitial());

    _notificationApi = NotificationApi(widget.apiClient);
    _notificationController = NotificationController(notificationApi: _notificationApi);
    // Note: We don't add a listener that calls setState here.
    // Instead, we use ListenableBuilder in the widget tree to only rebuild
    // the notification badge, not the entire screen.
    _streakController = StreakController(userApi: UserApi(widget.apiClient));
    _wasSignedIn = widget.auth.isLoggedIn;
    if (_wasSignedIn) {
      _notificationController.refreshUnreadCount();
      _syncTimezoneThenLoadStreak();
      _registerFcmToken();
    }
    widget.auth.addListener(_onAuthChanged);
    ShellNavigation.requests.addListener(_onShellRequest);
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

    // A stored session the server rejected: offer to log back in once.
    // Otherwise show the tour on a device's first launch.
    if (widget.auth.sessionExpired) {
      widget.auth.sessionExpired = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) requireAccount(context, widget.auth, AccountReason.sessionExpired);
      });
    } else {
      _checkAndShowTour();
    }
  }

  /// The shell stays mounted across sign-in and sign-out, so per-account
  /// setup that used to run in initState runs here on each transition.
  void _onAuthChanged() {
    final signedIn = widget.auth.isLoggedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;

    if (signedIn) {
      // Seen IDs queued while browsing as a guest now count for the account.
      // The feed keeps its loaded items so the user stays where they were.
      _flushPendingSeenIds();
      _registerFcmToken();
      _notificationController.refreshUnreadCount();
      _syncTimezoneThenLoadStreak();
      widget.shoppingListController.syncWithServer();
    } else {
      _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = null;
      widget.auth.onBeforeLogout = null;
      _notificationController.clear();
      _streakController.clear();
      _syncedTimezone = null; // the next account reports its own
      widget.shoppingListController.clearLocal();
      _ensureHomeTab();
      // Following needs an account, so a signed-out user goes back to For you.
      if (feed.scope == FeedScope.following) {
        feed.setScopeAndOptions(newScope: FeedScope.global);
      } else {
        feed.refresh();
      }
    }
  }

  /// Reports the device's timezone (only when it changed) so the server
  /// counts streak days at the user's own midnight, then loads the streak,
  /// which is counted in that zone. A failed report keeps the server's last
  /// zone (Georgian time by default) and still loads the streak.
  Future<void> _syncTimezoneThenLoadStreak() async {
    try {
      final timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (timezone != _syncedTimezone && widget.auth.isLoggedIn) {
        await UserApi(widget.apiClient).updateTimezone(timezone);
        _syncedTimezone = timezone;
      }
    } catch (_) {}
    if (widget.auth.isLoggedIn) await _streakController.load();
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
    final tourCompleted = await AppTourService.hasTourCompleted();
    if (!tourCompleted && mounted) {
      // Delay to ensure widgets are built
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          AppTourService.showTour(
            context,
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
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_onAuthChanged);
    ShellNavigation.requests.removeListener(_onShellRequest);
    _searchFocusRequests.dispose();
    feed.dispose();
    _feedViewController.dispose();
    _feedScrollController.dispose();
    _notificationController.dispose();
    _streakController.dispose();
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
        // The device may have changed timezone while in the background.
        _syncTimezoneThenLoadStreak();
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
    _fcmTokenRefreshSub?.cancel();
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

  /// Bumped to focus the Search tab's box (a second tap on Search).
  final ValueNotifier<int> _searchFocusRequests = ValueNotifier(0);

  /// A request from a screen deep in the stack (e.g. an empty state's
  /// "Explore recipes"); ShellNavigation.go has already popped back here.
  void _onShellRequest() {
    final request = ShellNavigation.requests.value;
    if (request == null || !mounted) return;
    switch (request) {
      case ShellRequest.home:
        _setPage(_homePage);
      case ShellRequest.searchFocus:
        _setPage(_searchPage);
        // After the tab is visible, so the field can take focus.
        WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusRequests.value++);
      case ShellRequest.create:
        _onAddRecipeTap();
    }
  }

  void _onSearchTap() {
    if (_currentIndex == _searchPage) {
      _searchFocusRequests.value++;
    } else {
      _setPage(_searchPage);
    }
  }

  void _onHomeTap() {
    if (_currentIndex == _homePage) {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      _setPage(_homePage);
    }
  }

  void _ensureHomeTab() {
    if (_currentIndex != _homePage) {
      setState(() {
        _currentIndex = _homePage;
      });
    }
  }

  Future<void> _onAddRecipeTap() async {
    if (!await requireVerifiedAccount(context, widget.auth, AccountReason.create)) return;
    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // This is the home route, which pages don't inset for (see
      // theme/status_bar.dart): each tab keeps below the status bar itself,
      // except the signed-in Profile tab, whose cover goes behind it. Only
      // the visible tab paints, so only its status-bar style applies.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StatusBarInset(
            child: HomeScreen(
              auth: widget.auth,
              apiClient: widget.apiClient,
              themeController: widget.themeController,
              languageController: widget.languageController,
              feed: feed,
              feedViewController: _feedViewController,
              scrollController: _feedScrollController,
              streakController: _streakController,
              onStreakTap: () => _setPage(_profilePage),
              onNotificationRefresh: () {
                if (widget.auth.isLoggedIn) _notificationController.refreshUnreadCount();
              },
              shoppingListController: widget.shoppingListController,
            ),
          ),
          StatusBarInset(
            child: SearchScreen(
              apiClient: widget.apiClient,
              auth: widget.auth,
              shoppingListController: widget.shoppingListController,
              focusRequests: _searchFocusRequests,
            ),
          ),
          StatusBarInset(
            child: NotificationsScreen(
              apiClient: widget.apiClient,
              auth: widget.auth,
              notificationController: _notificationController,
              shoppingListController: widget.shoppingListController,
            ),
          ),
          ProfileTabScreen(
            auth: widget.auth,
            apiClient: widget.apiClient,
            themeController: widget.themeController,
            languageController: widget.languageController,
            feedViewController: _feedViewController,
            shoppingListController: widget.shoppingListController,
            streakController: _streakController,
            isActive: _currentIndex == _profilePage,
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_notificationController, widget.auth]),
        builder: (context, _) {
          final me = widget.auth.me;
          return _BottomShellNavBar(
            currentIndex: _currentIndex,
            unreadCount: _notificationController.unreadCount,
            isSignedIn: widget.auth.isLoggedIn,
            username: me?["username"]?.toString() ?? "",
            avatarUrl: me?["avatar_url"]?.toString(),
            onHomeTap: _onHomeTap,
            onSearchTap: _onSearchTap,
            onAddRecipeTap: _onAddRecipeTap,
            onNotificationsTap: () {
              _setPage(_notificationsPage);
              if (widget.auth.isLoggedIn) _notificationController.silentRefresh();
            },
            onProfileTap: () => _setPage(_profilePage),
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

/// Home · Search · Add · Notifications · Profile, icons only.
class _BottomShellNavBar extends StatelessWidget {
  const _BottomShellNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.isSignedIn,
    required this.username,
    required this.avatarUrl,
    required this.onHomeTap,
    required this.onSearchTap,
    required this.onAddRecipeTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.feedKey,
    required this.searchKey,
    required this.createKey,
    required this.notificationsKey,
    required this.menuKey,
  });

  final int currentIndex;
  final int unreadCount;
  final bool isSignedIn;
  final String username;
  final String? avatarUrl;
  final VoidCallback onHomeTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAddRecipeTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final GlobalKey feedKey;
  final GlobalKey searchKey;
  final GlobalKey createKey;
  final GlobalKey notificationsKey;
  final GlobalKey menuKey;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);
    Color iconColor(int page) => currentIndex == page ? t.brandInk : t.ink2;

    final notificationsLabel = localizations?.notifications ?? "Notifications";
    final profileActive = currentIndex == _profilePage;
    final ringWidth = profileActive ? 2.0 : 1.5;

    // Material rather than a colored Container, so the slots' ink is visible.
    return Material(
      color: t.card,
      shape: Border(top: BorderSide(color: t.line)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavSlot(
                key: feedKey,
                label: localizations?.home ?? "Home",
                isActive: currentIndex == _homePage,
                onTap: onHomeTap,
                child: Icon(
                  currentIndex == _homePage ? Icons.home_rounded : Icons.home_outlined,
                  size: 24,
                  color: iconColor(_homePage),
                ),
              ),
              _NavSlot(
                key: searchKey,
                label: localizations?.search ?? "Search",
                isActive: currentIndex == _searchPage,
                onTap: onSearchTap,
                child: Icon(Icons.search_rounded, size: 24, color: iconColor(_searchPage)),
              ),
              _NavSlot(
                key: createKey,
                label: localizations?.add ?? "Add",
                onTap: onAddRecipeTap,
                child: Container(
                  width: 48,
                  height: 40,
                  decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                ),
              ),
              _NavSlot(
                key: notificationsKey,
                label: unreadCount > 0 ? "$notificationsLabel ($unreadCount)" : notificationsLabel,
                isActive: currentIndex == _notificationsPage,
                onTap: onNotificationsTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_outlined, size: 24, color: iconColor(_notificationsPage)),
                    if (unreadCount > 0)
                      Positioned(
                        left: 12,
                        top: -7,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.badge,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: t.card, width: 2),
                          ),
                          child: Text(
                            unreadCount > 99 ? "99+" : unreadCount.toString(),
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _NavSlot(
                key: menuKey,
                label: localizations?.profile ?? "Profile",
                isActive: profileActive,
                onTap: onProfileTap,
                child: isSignedIn
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: profileActive ? t.brand : t.line, width: ringWidth),
                        ),
                        child: ProfileAvatar(
                          avatarUrl: avatarUrl,
                          name: username,
                          size: 28 - 2 * ringWidth,
                        ),
                      )
                    : Icon(Icons.person_outline_rounded, size: 24, color: iconColor(_profilePage)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One equal-width bottom-nav slot. Tab slots get the 4×4 active dot under
/// the icon (with a matching spacer above, so icons stay centered); Add has
/// no dot and no selected state.
class _NavSlot extends StatelessWidget {
  const _NavSlot({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.isActive,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  /// Null for Add, which is an action rather than a tab.
  final bool? isActive;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isTab = isActive != null;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isTab) const SizedBox(height: 8),
              child,
              if (isTab) ...[
                const SizedBox(height: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive! ? t.brand : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
