import "dart:math" as math;

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../feed/feed_models.dart";
import "../feed/feed_view_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/app_tokens.dart";
import "../theme/theme_controller.dart";
import "../users/streak_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/profile_avatar.dart";
import "edit_profile_screen.dart";
import "followers_screen.dart";
import "following_screen.dart";
import "profile_screen.dart";
import "saved_recipes_screen.dart";
import "settings_screen.dart";
import "shared_recipes_screen.dart";
import "shared_shopping_lists_screen.dart";
import "shopping_list_screen.dart";

/// The Profile tab of the shell: the user's identity, stats, streak, library
/// and latest recipes, with settings (and sign out) behind the gear. Guests
/// get a sign-up card instead of the personal sections.
///
/// This is not [ProfileScreen] with a flag: that screen's own-profile layout
/// differs in every section, and its recipe list is bound to one username for
/// its lifetime, while this tab stays mounted across sign-in and sign-out.
/// "See all" and the identity row open [ProfileScreen] for the full view
/// (all recipes, liked/saved tabs, avatar and cover photo).
class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.feedViewController,
    required this.shoppingListController,
    required this.streakController,
    required this.isActive,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final FeedViewController feedViewController;
  final ShoppingListController shoppingListController;
  final StreakController streakController;

  /// True while this is the visible tab. The data reloads every time it turns
  /// true, the way the old drawer reloaded every time it opened.
  final bool isActive;

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  /// Recipes shown on the tab; "See all" has the rest.
  static const _recipePreviewCount = 6;

  /// The account the data below belongs to (null for guests).
  String? _username;
  UserProfile? _profile;
  LibraryCounts? _libraryCounts;
  UserRecipesController? _recipes;

  @override
  void initState() {
    super.initState();
    _username = _currentUsername;
    widget.auth.addListener(_onAuthChanged);
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant ProfileTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _recipes?.removeListener(_onRecipesChanged);
    _recipes?.dispose();
    super.dispose();
  }

  String? get _currentUsername {
    if (!widget.auth.isLoggedIn) return null;
    final username = widget.auth.me?["username"]?.toString();
    return (username == null || username.isEmpty) ? null : username;
  }

  void _onAuthChanged() {
    final username = _currentUsername;
    if (username != _username) {
      _username = username;
      _profile = null;
      _libraryCounts = null;
      _recipes?.removeListener(_onRecipesChanged);
      _recipes?.dispose();
      _recipes = null;
      if (widget.isActive) _load();
    }
    // Also covers a changed display name or avatar on the same account.
    if (mounted) setState(() {});
  }

  void _onRecipesChanged() {
    if (mounted) setState(() {});
  }

  UserRecipesController _recipesFor(String username) {
    var recipes = _recipes;
    if (recipes == null) {
      recipes = UserRecipesController(userApi: UserApi(widget.apiClient), username: username);
      recipes.addListener(_onRecipesChanged);
      _recipes = recipes;
    }
    return recipes;
  }

  /// Reloads profile stats, library counts and the streak. The recipe grid
  /// reloads on [force] (pull to refresh), on first load, or when the recipe
  /// count changed, so switching tabs doesn't blank it every time.
  Future<void> _load({bool force = false}) async {
    final username = _username;
    if (username == null) return;
    final recipes = _recipesFor(username);
    final firstLoad = recipes.items.isEmpty;
    final countBefore = _profile?.recipesCount;
    await Future.wait([
      _loadProfileAndCounts(username),
      widget.streakController.load(),
      if (force || firstLoad) recipes.loadInitial(),
    ]);
    if (!force && !firstLoad && mounted && _profile?.recipesCount != countBefore) {
      await recipes.refresh();
    }
  }

  Future<void> _loadProfileAndCounts(String username) async {
    final userApi = UserApi(widget.apiClient);
    try {
      final results = await Future.wait([
        userApi.getUserProfile(username),
        userApi.getLibraryCounts(),
      ]);
      if (!mounted || username != _username) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _libraryCounts = results[1] as LibraryCounts;
      });
    } catch (_) {}
  }

  /// Asks a guest for an account first, then runs [open].
  Future<void> _requireAccountThen(
    AccountReason reason,
    void Function(NavigatorState) open,
  ) async {
    final navigator = Navigator.of(context);
    if (!await requireAccount(context, widget.auth, reason)) return;
    if (navigator.mounted) open(navigator);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openSettings() {
    _push(SettingsScreen(
      themeController: widget.themeController,
      languageController: widget.languageController,
      feedViewController: widget.feedViewController,
      auth: widget.auth,
      apiClient: widget.apiClient,
    ));
  }

  void _openFullProfile() {
    _push(ProfileScreen(
      auth: widget.auth,
      apiClient: widget.apiClient,
      shoppingListController: widget.shoppingListController,
    ));
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditProfileScreen(auth: widget.auth, apiClient: widget.apiClient),
    ));
    if (result == true) {
      await widget.auth.bootstrap();
      await _load();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final signedIn = widget.auth.isLoggedIn;
    const gap = SizedBox(height: 24);

    return Material(
      color: t.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(t, l),
            Expanded(
              child: RefreshIndicator(
                color: t.brandInk,
                onRefresh: () => _load(force: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (signedIn) ...[
                      _buildIdentity(t),
                      gap,
                      _buildStatsCard(t, l),
                      gap,
                      _buildEditProfileButton(t, l),
                      gap,
                      ListenableBuilder(
                        listenable: widget.streakController,
                        builder: (context, _) => widget.streakController.loaded
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _buildStreakCard(t, l),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ] else ...[
                      _buildGuestCard(t, l),
                      gap,
                    ],
                    _buildLibrary(t, l, signedIn),
                    if (signedIn) ...[
                      gap,
                      _buildMyRecipes(t, l),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppTokens t, AppLocalizations? l) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l?.profile ?? "Profile",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.ink),
                ),
              ),
            ),
            IconButton(
              onPressed: _openSettings,
              tooltip: l?.settings ?? "Settings",
              icon: Icon(Icons.settings_outlined, color: t.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentity(AppTokens t) {
    final me = widget.auth.me;
    final username = me?["username"]?.toString() ?? "";
    final displayName = me?["display_name"]?.toString();
    final name = (displayName == null || displayName.isEmpty) ? username : displayName;

    return InkWell(
      onTap: _openFullProfile,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          // 3px gap in the screen color, then a 2px brand ring.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.brand, width: 2),
            ),
            child: ProfileAvatar(avatarUrl: me?["avatar_url"]?.toString(), name: username, size: 72),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  "@$username",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: t.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(AppTokens t, AppLocalizations? l) {
    final profile = _profile;
    final username = _username;
    final divider = VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: t.line);

    return Material(
      color: t.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatCell(value: profile?.recipesCount, label: l?.recipes ?? "Recipes"),
            divider,
            _StatCell(
              value: profile?.followersCount,
              label: l?.followers ?? "Followers",
              onTap: username == null
                  ? null
                  : () => _push(FollowersScreen(
                        username: username,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                      )),
            ),
            divider,
            _StatCell(
              value: profile?.followingCount,
              label: l?.followingTitle ?? "Following",
              onTap: username == null
                  ? null
                  : () => _push(FollowingScreen(
                        username: username,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                      )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileButton(AppTokens t, AppLocalizations? l) {
    return OutlinedButton(
      onPressed: _openEditProfile,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: t.card,
        foregroundColor: t.ink,
        side: BorderSide(color: t.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(l?.editProfile ?? "Edit Profile"),
    );
  }

  Widget _buildStreakCard(AppTokens t, AppLocalizations? l) {
    final streak = widget.streakController;
    final n = streak.currentStreak;
    // UTC, like the server's streak days, so the dots always match [n].
    final done = streak.streakDatesUtc;
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekday = DateFormat.E(Localizations.localeOf(context).languageCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_fire_department_rounded, color: t.brandInk, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l?.streakCardTitle(n) ?? "$n-day streak",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l?.streakKeepGoing ?? "Keep your streak going today",
                      style: TextStyle(fontSize: 13, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The count in the title already says it; the strip is visual only.
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _StreakDay(
                      label: weekday.format(monday.add(Duration(days: i))),
                      isToday: monday.add(Duration(days: i)) == today,
                      isDone: done.contains(monday.add(Duration(days: i))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCard(AppTokens t, AppLocalizations? l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset("assets/icon/app_icon.png", width: 48, height: 48, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l?.guestDrawerTitle ?? "Join Yummy",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l?.guestDrawerBody ?? "Save recipes, follow cooks and share your own.",
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => requireAccount(context, widget.auth, AccountReason.account),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: t.fill,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(l?.guestSignUpOrLogIn ?? "Sign up or log in"),
          ),
        ],
      ),
    );
  }

  /// Saved, shopping list, shared recipes and shared lists. Guests see the
  /// same entries and get the account prompt on tap.
  Widget _buildLibrary(AppTokens t, AppLocalizations? l, bool signedIn) {
    final counts = _libraryCounts;
    final countsLoading = signedIn && counts == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l?.library ?? "Library",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink2),
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _LibraryTile(
                  icon: Icons.bookmark_outline_rounded,
                  title: l?.savedRecipes ?? "Saved Recipes",
                  loading: countsLoading,
                  subtitle: counts != null
                      ? l?.nSaved(counts.savedRecipes) ?? "${counts.savedRecipes} saved"
                      : null,
                  onTap: () => _requireAccountThen(AccountReason.save, (navigator) {
                    navigator.push(MaterialPageRoute(
                      builder: (_) => SavedRecipesScreen(
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                      ),
                    ));
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.shoppingListController,
                  builder: (context, _) {
                    final count = widget.shoppingListController.totalCount;
                    return _LibraryTile(
                      icon: Icons.shopping_cart_outlined,
                      title: l?.shoppingList ?? "Shopping List",
                      subtitle: signedIn ? "$count ${l?.items ?? "items"}" : null,
                      onTap: () => _requireAccountThen(AccountReason.shoppingList, (navigator) {
                        navigator.push(MaterialPageRoute(
                          builder: (_) => ShoppingListScreen(
                            controller: widget.shoppingListController,
                            apiClient: widget.apiClient,
                            auth: widget.auth,
                          ),
                        ));
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: t.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: t.line),
          ),
          child: Column(
            children: [
              _LibraryRow(
                icon: Icons.people_outline_rounded,
                label: l?.sharedRecipes ?? "Shared Recipes",
                count: counts?.sharedRecipes,
                loading: countsLoading,
                onTap: () => _requireAccountThen(AccountReason.account, (navigator) {
                  navigator.push(MaterialPageRoute(
                    builder: (_) => SharedRecipesScreen(
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                    ),
                  ));
                }),
              ),
              Divider(height: 1, thickness: 1, color: t.line),
              _LibraryRow(
                icon: Icons.list_alt_rounded,
                label: l?.sharedShoppingLists ?? "Shared Shopping Lists",
                count: counts?.sharedShoppingLists,
                loading: countsLoading,
                onTap: () => _requireAccountThen(AccountReason.account, (navigator) {
                  navigator.push(MaterialPageRoute(
                    builder: (_) => SharedShoppingListsScreen(
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                    ),
                  ));
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyRecipes(AppTokens t, AppLocalizations? l) {
    final recipes = _recipes;
    final items = recipes?.items ?? const <FeedItem>[];
    final total = _profile?.recipesCount ?? items.length;

    final Widget body;
    if (recipes == null || (recipes.isLoading && items.isEmpty)) {
      body = SizedBox(
        height: 132,
        child: Center(child: CircularProgressIndicator(color: t.brandInk)),
      );
    } else if (recipes.error != null && items.isEmpty) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: recipes.loadInitial,
          style: TextButton.styleFrom(foregroundColor: t.brandInk),
          child: Text(l?.retry ?? "Retry"),
        ),
      );
    } else if (items.isEmpty) {
      body = Text(
        "${l?.noRecipesYet ?? "No recipes yet"}. ${l?.createYourFirstRecipe ?? "Create your first recipe!"}",
        style: TextStyle(fontSize: 13, color: t.ink2),
      );
    } else {
      final shown = items.take(_recipePreviewCount).toList();
      body = Column(
        children: [
          for (var i = 0; i < shown.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < shown.length ? 16 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _RecipeTile(recipe: shown[i], onTap: () => _openRecipe(shown[i]))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < shown.length
                        ? _RecipeTile(recipe: shown[i + 1], onTap: () => _openRecipe(shown[i + 1]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l?.myRecipes ?? "My recipes",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
                      ),
                      TextSpan(
                        text: "  $total",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink2),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            TextButton(
              onPressed: _openFullProfile,
              style: TextButton.styleFrom(
                foregroundColor: t.brandInk,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: Text(l?.seeAll ?? "See all"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  void _openRecipe(FeedItem recipe) {
    _push(RecipeDetailScreen(
      recipeId: recipe.id,
      apiClient: widget.apiClient,
      auth: widget.auth,
      shoppingListController: widget.shoppingListController,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, this.onTap});

  /// Null while the profile is loading.
  final int? value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (value == null)
                const _SkeletonPill(width: 28, height: 18)
              else
                Text(
                  "$value",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
                ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakDay extends StatelessWidget {
  const _StreakDay({required this.label, required this.isToday, required this.isDone});

  final String label;
  final bool isToday;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final Widget dot;
    if (isDone) {
      dot = Container(
        decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
      );
    } else if (isToday) {
      dot = CustomPaint(painter: _DashedRingPainter(t.brand));
    } else {
      dot = Container(
        decoration: BoxDecoration(
          color: t.bg,
          shape: BoxShape.circle,
          border: Border.all(color: t.line),
        ),
      );
    }

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? t.ink : t.ink2,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(width: 30, height: 30, child: dot),
      ],
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.0;
    const dashes = 12;
    const step = 2 * math.pi / dashes;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => oldDelegate.color != color;
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
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
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Material(
      color: t.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: t.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: t.brandInk),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
              ),
              if (loading) ...[
                const SizedBox(height: 4),
                const _SkeletonPill(width: 48, height: 14),
              ] else if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 13, color: t.ink2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 22, color: t.ink2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.ink),
                ),
              ),
              if (loading)
                const _SkeletonPill(width: 20, height: 14)
              else if (count != null)
                Text("$count", style: TextStyle(fontSize: 14, color: t.ink2)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.ink2),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe, required this.onTap});

  final FeedItem recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final image = recipe.images.isNotEmpty ? recipe.images.first : null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: image != null
                      ? RecipeImageWidget(
                          imageUrl: image.url,
                          width: double.infinity,
                          height: 132,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                        )
                      : const RecipeFallbackImage(iconSize: 32),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing placeholder for a count that is still loading (moved here from
/// the removed drawer).
class _SkeletonPill extends StatefulWidget {
  const _SkeletonPill({this.width = 40, this.height = 10});

  final double width;
  final double height;

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
    final base = AppTokens.of(context).ink2;
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
