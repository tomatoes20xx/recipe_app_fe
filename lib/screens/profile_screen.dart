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
import "../utils/ui_utils.dart";
import "../theme/app_tokens.dart";
import "../widgets/common/common_widgets.dart";
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _userProfile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error ?? (AppLocalizations.of(context)?.userNotFound ?? "User not found"),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadUserProfile,
                child: Text(AppLocalizations.of(context)?.retry ?? "Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            ..._buildContentSlivers(context),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final safeTop = MediaQuery.of(context).padding.top;

    final profile = _userProfile!;
    final username = profile.username;
    final displayName = profile.displayName ?? profile.username;
    final avatarUrl = profile.avatarUrl;
    final bio = profile.bio;

    final normalizedAvatarUrl =
        (avatarUrl == null || avatarUrl.isEmpty || avatarUrl == "null")
            ? null
            : avatarUrl;

    final coverImageUrl = profile.coverPhotoUrl;

    const coverHeight = 180.0;
    const avatarSize = 96.0;
    const overlapAmount = 56.0;
    const avatarOverflow = avatarSize - overlapAmount; // 40px below cover

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Cover + top bar + avatar ──────────────────────────
        SizedBox(
          height: coverHeight + avatarOverflow,
          child: Stack(
            children: [
              // Cover image
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverHeight,
                child: coverImageUrl != null
                    ? RecipeImageWidget(
                        imageUrl: coverImageUrl,
                        width: double.infinity,
                        height: coverHeight,
                        fit: BoxFit.cover,
                        cacheHeight: 360,
                      )
                    : const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF5AAE94), Color(0xFF2E7A5A)],
                          ),
                        ),
                        child: SizedBox(
                            height: coverHeight, width: double.infinity),
                      ),
              ),
              // Scrim
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4],
                    ),
                  ),
                ),
              ),
              // Top bar
              Positioned(
                top: safeTop + 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    _TopBarButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (!profile.isViewer)
                      _TopBarButton(
                        icon: Icons.more_vert,
                        onTap: () => _showMoreMenu(context),
                      ),
                  ],
                ),
              ),
              // Avatar
              Positioned(
                top: coverHeight - overlapAmount,
                left: 20,
                child: _buildAvatar(
                    context, normalizedAvatarUrl, username, theme),
              ),
            ],
          ),
        ),

        // ── Name, stats, actions ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "@$username",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  bio,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Stats card
              _StatsCard(
                followersCount: profile.followersCount,
                followingCount: profile.followingCount,
                totalLikes: profile.totalLikesCount,
                username: username,
                auth: widget.auth,
                apiClient: widget.apiClient,
                shoppingListController: widget.shoppingListController,
              ),
              // Your own public profile has nothing to follow.
              if (!profile.isViewer) ...[
                const SizedBox(height: 14),
                _OtherActionRow(
                  isFollowing: _isFollowing,
                  onFollow: _toggleFollow,
                ),
              ],
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, String? avatarUrl, String username,
      ThemeData theme) {
    Widget avatarContent;
    if (avatarUrl != null) {
      avatarContent = RecipeImageWidget(
        imageUrl: avatarUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        cacheWidth: 192,
        cacheHeight: 192,
      );
    } else {
      avatarContent = Container(
        width: 96,
        height: 96,
        color: theme.colorScheme.primary,
        child: Center(
          child: username.isNotEmpty
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Icon(Icons.person_outline_rounded,
                  size: 48, color: theme.colorScheme.onPrimary),
        ),
      );
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.surface, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: avatarContent,
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

  List<Widget> _buildContentSlivers(BuildContext context) {
    final controller = _recipesController;

    if (controller.isLoading && controller.items.isEmpty) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (controller.error != null && controller.items.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: ErrorStateWidget(
              message: controller.error!,
              onRetry: controller.loadInitial,
            ),
          ),
        ),
      ];
    }

    if (controller.items.isEmpty) {
      final localizations = AppLocalizations.of(context);
      return [
        SliverFillRemaining(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              icon: Icons.restaurant_menu_outlined,
              title: localizations?.noRecipesYet ?? "No recipes yet",
              description: localizations?.userNoRecipesYet ?? "This user hasn't created any recipes yet",
            ),
          ),
        ),
      ];
    }

    final recipeCount = controller.items.length;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            AppLocalizations.of(context)?.recipeCount(recipeCount) ??
                "$recipeCount Recipes",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= controller.items.length) {
                return Container(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerLow,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final recipe = controller.items[index];
              return RepaintBoundary(
                child: RecipeGridCard(
                  recipe: recipe,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipeId: recipe.id,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: controller.items.length +
                (controller.isLoadingMore ? 1 : 0),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.75,
          ),
        ),
      ),
      if (controller.isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        // White circle in both themes: keep the light theme's green.
        child: Icon(icon, size: 22, color: AppTokens.light.brandInk),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.followersCount,
    required this.followingCount,
    required this.totalLikes,
    required this.username,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
  });

  final int followersCount;
  final int followingCount;
  final int totalLikes;
  final String username;
  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          _StatCell(
            value: followersCount.toString(),
            label: localizations?.followers ?? "Followers",
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FollowersScreen(
                username: username,
                apiClient: apiClient,
                auth: auth,
                shoppingListController: shoppingListController,
              ),
            )),
            leftRadius: 16,
          ),
          _StatDivider(),
          _StatCell(
            value: followingCount.toString(),
            label: localizations?.followingTitle ?? "Following",
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FollowingScreen(
                username: username,
                apiClient: apiClient,
                auth: auth,
                shoppingListController: shoppingListController,
              ),
            )),
          ),
          _StatDivider(),
          _StatCell(
            value: totalLikes.toString(),
            label: localizations?.totalLikes ?? "Likes",
            rightRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.onTap,
    this.leftRadius = 0,
    this.rightRadius = 0,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;
  final double leftRadius;
  final double rightRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Expanded(child: Center(child: content));
    }

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(leftRadius),
            bottomLeft: Radius.circular(leftRadius),
            topRight: Radius.circular(rightRadius),
            bottomRight: Radius.circular(rightRadius),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    );
  }
}

class _OtherActionRow extends StatelessWidget {
  const _OtherActionRow({
    required this.isFollowing,
    required this.onFollow,
  });

  final bool isFollowing;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: onFollow,
        icon: Icon(
          isFollowing ? Icons.check : Icons.person_add_outlined,
          size: 18,
        ),
        label: Text(isFollowing
            ? (AppLocalizations.of(context)?.followingUser ?? "Following")
            : (AppLocalizations.of(context)?.follow ?? "Follow")),
        style: FilledButton.styleFrom(
          backgroundColor: isFollowing
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.onSurface,
          foregroundColor: isFollowing
              ? theme.colorScheme.onSurface
              : theme.colorScheme.surface,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
