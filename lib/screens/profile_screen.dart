import "package:flutter/material.dart";

import "../analytics/analytics_service.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../reports/report_bottom_sheet.dart";
import "../reports/report_models.dart";
import "../shopping/shopping_list_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/error_utils.dart";
import "../theme/app_tokens.dart";
import "../feed/feed_models.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/common/profile_stats_card.dart";
import "../widgets/common/recipe_grid_tile.dart";
import "../widgets/common/skeletons.dart";
import "../widgets/profile/profile_cover_header.dart";
import "../widgets/empty_state_widget.dart";
import "followers_screen.dart";
import "following_screen.dart";

/// A user's public profile. Opening your own username shows this public view
/// too (how others see you); your editable profile is the shell's Profile tab.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
    required this.username,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final String username;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingProfile = false;
  bool _isFollowing = false;
  UserProfile? _userProfile;
  String? _error;

  late final UserRecipesController _recipesController;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _recipesController = UserRecipesController(
      userApi: UserApi(widget.apiClient),
      username: widget.username,
    );
    _recipesController.addListener(_onContentChanged);
    _recipesController.loadInitial();

    _loadUserProfile();

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 300) return;
    _recipesController.loadMore();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _recipesController.removeListener(_onContentChanged);
    _recipesController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    await _loadUserProfile();
    await _recipesController.refresh();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });
    try {
      final profile =
          await UserApi(widget.apiClient).getUserProfile(widget.username);
      setState(() {
        _userProfile = profile;
        _isFollowing = profile.viewerIsFollowing;
        _isLoadingProfile = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingProfile = false;
      });
    }
  }

  /// Gate for actions on another user's profile. After a fresh sign-in the
  /// profile is reloaded so follow/block state is the account's, not the
  /// guest's. Returns false if the user backed out or it's their own profile.
  Future<bool> _requireAccountHere(AccountReason reason, {bool verified = false}) async {
    final wasGuest = !widget.auth.isLoggedIn;
    final ok = verified
        ? await requireVerifiedAccount(context, widget.auth, reason)
        : await requireAccount(context, widget.auth, reason);
    if (!ok || !mounted) return false;
    if (wasGuest) {
      try {
        final profile = await UserApi(widget.apiClient).getUserProfile(widget.username);
        if (!mounted) return false;
        setState(() {
          _userProfile = profile;
          _isFollowing = profile.viewerIsFollowing;
        });
        if (profile.isViewer) return false;
      } catch (_) {}
    }
    return mounted;
  }

  Future<void> _toggleFollow() async {
    if (_userProfile == null) return;
    final wasGuest = !widget.auth.isLoggedIn;
    if (!await _requireAccountHere(AccountReason.follow, verified: true)) return;
    // Just signed in to an account that already follows them.
    if (wasGuest && _isFollowing) return;

    final oldFollowing = _isFollowing;
    final newFollowing = !_isFollowing;
    setState(() {
      _isFollowing = newFollowing;
      _userProfile = _userProfile!.copyWith(
        viewerIsFollowing: newFollowing,
        followersCount: _userProfile!.followersCount + (newFollowing ? 1 : -1),
      );
    });

    try {
      final userApi = UserApi(widget.apiClient);
      if (newFollowing) {
        await userApi.followUser(widget.username);
        AnalyticsService().logFollow(widget.username);
      } else {
        await userApi.unfollowUser(widget.username);
        AnalyticsService().logUnfollow(widget.username);
      }
      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          newFollowing
              ? (AppLocalizations.of(context)
                      ?.nowFollowingUser(_userProfile!.username) ??
                  "Now following ${_userProfile!.username}")
              : (AppLocalizations.of(context)
                      ?.unfollowedUser(_userProfile!.username) ??
                  "Unfollowed ${_userProfile!.username}"),
        );
      }
    } catch (e) {
      setState(() {
        _isFollowing = oldFollowing;
        _userProfile = _userProfile!.copyWith(
          viewerIsFollowing: oldFollowing,
          followersCount:
              _userProfile!.followersCount + (oldFollowing ? 1 : -1),
        );
      });
      if (mounted &&
          !await handleAuthError(context, widget.auth, e, AccountReason.follow) &&
          mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _handleBlockUser() async {
    if (_userProfile == null) return;
    if (!await _requireAccountHere(AccountReason.block) || !mounted) return;
    final profile = _userProfile;
    if (profile == null) return;

    final isCurrentlyBlocked = profile.viewerIsBlocked;

    if (!isCurrentlyBlocked) {
      final localizations = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localizations?.blockUser ?? "Block User"),
          content: Text(
            localizations?.blockUserConfirm(profile.username) ??
                "Are you sure you want to block @${profile.username}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations?.cancel ?? "Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                localizations?.blockUser ?? "Block",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _userProfile =
          _userProfile!.copyWith(viewerIsBlocked: !isCurrentlyBlocked);
    });

    try {
      final userApi = UserApi(widget.apiClient);
      if (!isCurrentlyBlocked) {
        await userApi.blockUser(profile.username);
      } else {
        await userApi.unblockUser(profile.username);
      }
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          !isCurrentlyBlocked
              ? (localizations?.userBlocked ?? "User blocked")
              : (localizations?.userUnblocked ?? "User unblocked"),
        );
      }
    } catch (e) {
      setState(() {
        _userProfile =
            _userProfile!.copyWith(viewerIsBlocked: isCurrentlyBlocked);
      });
      if (mounted) ErrorUtils.showError(context, e);
    }
  }

  Future<void> _handleReportUser() async {
    if (_userProfile == null) return;
    if (!await _requireAccountHere(AccountReason.report)) return;
    final profile = _userProfile;
    if (profile == null || !mounted) return;
    await showReportBottomSheet(
      context: context,
      targetType: ReportTargetType.user,
      targetId: profile.id,
      apiClient: widget.apiClient,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  /// Same cover height as the Profile tab's (300 there includes the status
  /// bar, which a pushed page already sits below).
  static const _coverHeight = 256.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final profile = _userProfile;

    if (profile == null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(),
        body: _isLoadingProfile
            ? Center(child: CircularProgressIndicator(color: t.brandInk))
            : ErrorStateWidget(
                message: _error ?? (l?.userNotFound ?? "User not found"),
                onRetry: _loadUserProfile,
              ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: RefreshIndicator(
        color: t.brandInk,
        onRefresh: _refreshProfile,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileCoverHeaderDelegate(
                minExtent: profileCoverToolbarHeight,
                maxExtent: _coverHeight,
                builder: (context, collapse) => _buildCoverHeader(t, l, profile, collapse),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(
                children: [
                  if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                    Text(profile.bio!.trim(), style: TextStyle(fontSize: 15, height: 1.5, color: t.ink)),
                    const SizedBox(height: 16),
                  ],
                  _buildStatsCard(l, profile),
                  // Your own public profile has nothing to follow.
                  if (!profile.isViewer) ...[
                    const SizedBox(height: 16),
                    _FollowButton(isFollowing: _isFollowing, onPressed: _toggleFollow),
                  ],
                  const SizedBox(height: 24),
                  _buildRecipesHeader(t, l, profile),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            ..._buildContentSlivers(context),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildCoverHeader(AppTokens t, AppLocalizations? l, UserProfile profile, double collapse) {
    final name = profile.displayName?.trim().isNotEmpty == true ? profile.displayName!.trim() : profile.username;
    final back = MaterialLocalizations.of(context).backButtonTooltip;
    final more = l?.moreOptions ?? "More options";

    return ProfileCoverHeader(
      collapse: collapse,
      expandedHeight: _coverHeight,
      topInset: 0,
      coverUrl: profile.coverPhotoUrl,
      name: name,
      username: profile.username,
      avatar: ProfileCoverAvatar(avatarUrl: profile.avatarUrl, name: profile.username),
      coverLeading: ProfileCoverButton(
        tooltip: back,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
      coverActions: [
        if (!profile.isViewer)
          ProfileCoverButton(
            tooltip: more,
            onPressed: () => _showMoreMenu(context),
            icon: const Icon(Icons.more_vert_rounded, size: 20),
          ),
      ],
      toolbarLeading: IconButton(
        tooltip: back,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: t.ink),
      ),
      toolbarActions: [
        if (!profile.isViewer)
          IconButton(
            tooltip: more,
            onPressed: () => _showMoreMenu(context),
            icon: Icon(Icons.more_vert_rounded, color: t.ink),
          ),
      ],
    );
  }

  /// The Profile tab's stats card: recipes, followers, following.
  Widget _buildStatsCard(AppLocalizations? l, UserProfile profile) {
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return ProfileStatsCard(
      stats: [
        ProfileStat(value: profile.recipesCount, label: l?.recipes ?? "Recipes"),
        ProfileStat(
          value: profile.followersCount,
          label: l?.followers ?? "Followers",
          onTap: () => push(FollowersScreen(
            username: profile.username,
            apiClient: widget.apiClient,
            auth: widget.auth,
            shoppingListController: widget.shoppingListController,
          )),
        ),
        ProfileStat(
          value: profile.followingCount,
          label: l?.followingTitle ?? "Following",
          onTap: () => push(FollowingScreen(
            username: profile.username,
            apiClient: widget.apiClient,
            auth: widget.auth,
            shoppingListController: widget.shoppingListController,
          )),
        ),
      ],
    );
  }

  /// "Recipes  12", like the Profile tab's "My recipes" header.
  Widget _buildRecipesHeader(AppTokens t, AppLocalizations? l, UserProfile profile) {
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: l?.recipes ?? "Recipes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
            ),
            TextSpan(
              text: "  ${profile.recipesCount}",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink2),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 14),
              child: SheetHandle(),
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                AppLocalizations.of(context)?.reportUser ?? "Report User",
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleReportUser();
              },
            ),
            ListTile(
              leading: Icon(
                _userProfile?.viewerIsBlocked == true
                    ? Icons.person_add_outlined
                    : Icons.block_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                _userProfile?.viewerIsBlocked == true
                    ? (AppLocalizations.of(context)?.unblockUser ??
                        "Unblock User")
                    : (AppLocalizations.of(context)?.blockUser ??
                        "Block User"),
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleBlockUser();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTENT SLIVERS (recipe grid)
  // ─────────────────────────────────────────────────────────────

  /// The user's recipes as the Profile tab shows them: 2-column photo +
  /// title tiles, loaded page by page as the list scrolls.
  List<Widget> _buildContentSlivers(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final controller = _recipesController;
    final items = controller.items;
    const padding = EdgeInsets.fromLTRB(16, 0, 16, 24);

    if (controller.isLoading && items.isEmpty) {
      return const [
        SliverPadding(padding: padding, sliver: SliverToBoxAdapter(child: RecipeGridSkeleton())),
      ];
    }
    if (controller.error != null && items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorStateWidget(message: controller.error!, onRetry: controller.loadInitial),
        ),
      ];
    }
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              icon: Icons.restaurant_menu_outlined,
              title: l?.noRecipesYet ?? "No recipes yet",
              description: l?.userNoRecipesYet ?? "This user hasn't created any recipes yet",
            ),
          ),
        ),
      ];
    }

    final rows = (items.length + 1) ~/ 2;
    return [
      SliverPadding(
        padding: padding,
        sliver: SliverList.builder(
          itemCount: rows + (controller.isLoadingMore ? 1 : 0),
          itemBuilder: (context, row) {
            if (row >= rows) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: t.brandInk)),
              );
            }
            final i = row * 2;
            return Padding(
              padding: EdgeInsets.only(bottom: row < rows - 1 ? 16 : 0),
              child: RecipeGridRow(
                left: items[i],
                right: i + 1 < items.length ? items[i + 1] : null,
                onTap: _openRecipe,
              ),
            );
          },
        ),
      ),
    ];
  }

  void _openRecipe(FeedItem recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipe.id,
          apiClient: widget.apiClient,
          auth: widget.auth,
          shoppingListController: widget.shoppingListController,
        ),
      ),
    );
  }
}

/// Follow / Following, full width like the Profile tab's Edit profile
/// button: the primary button to follow, the outlined one once following.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onPressed});

  final bool isFollowing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const textStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    if (isFollowing) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(l?.followingUser ?? "Following"),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          backgroundColor: t.card,
          foregroundColor: t.ink,
          side: BorderSide(color: t.line),
          shape: shape,
          textStyle: textStyle,
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.person_add_outlined, size: 18),
      label: Text(l?.follow ?? "Follow"),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: shape,
        textStyle: textStyle,
      ),
    );
  }
}
