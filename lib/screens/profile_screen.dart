import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../analytics/analytics_service.dart";
import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_models.dart";
import "../feed/saved_recipes_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../reports/report_bottom_sheet.dart";
import "../reports/report_models.dart";
import "../shopping/shopping_list_controller.dart";
import "../users/liked_recipes_controller.dart";
import "../users/streak_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/email_verification_gate.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";
import "../utils/paginated_list_controller.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/empty_state_widget.dart";
import "edit_profile_screen.dart";
import "followers_screen.dart";
import "following_screen.dart";
import "image_crop_screen.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
    this.username,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final String? username;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;
  bool _isSettingCover = false;
  bool _isLoadingProfile = false;
  bool _isFollowing = false;
  UserProfile? _userProfile;
  String? _error;
  StreakController? _streakController;

  late final UserRecipesController? _recipesController;
  LikedRecipesController? _likedController;
  SavedRecipesController? _savedController;
  TabController? _tabController;

  final ScrollController _scrollController = ScrollController();

  bool get _isSelf => widget.username == null;

  @override
  void initState() {
    super.initState();

    final targetUsername =
        widget.username ?? widget.auth.me?["username"]?.toString();
    if (targetUsername != null) {
      _recipesController = UserRecipesController(
        userApi: UserApi(widget.apiClient),
        username: targetUsername,
      );
      _recipesController!.addListener(_onContentChanged);
      _recipesController.loadInitial();
    } else {
      _recipesController = null;
    }

    if (_isSelf) {
      _tabController = TabController(length: 3, vsync: this);
      _tabController!.addListener(_onTabChanged);

      final userApi = UserApi(widget.apiClient);
      _likedController = LikedRecipesController(userApi: userApi);
      _likedController!.addListener(_onContentChanged);

      _savedController = SavedRecipesController(userApi: userApi);
      _savedController!.addListener(_onContentChanged);

      _loadOwnProfile();
      _loadStreak();
    } else {
      _loadUserProfile();
    }

    _scrollController.addListener(_onScroll);
  }

  void _onTabChanged() {
    if (_tabController!.indexIsChanging) return;
    final tab = _tabController!.index;
    if (tab == 1 &&
        _likedController!.items.isEmpty &&
        !_likedController!.isLoading) {
      _likedController!.loadInitial();
    }
    if (tab == 2 &&
        _savedController!.items.isEmpty &&
        !_savedController!.isLoading) {
      _savedController!.loadInitial();
    }
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 300) return;
    _activeController?.loadMore();
  }

  PaginatedListController<FeedItem>? get _activeController {
    if (!_isSelf) return _recipesController;
    switch (_tabController?.index ?? 0) {
      case 1:
        return _likedController;
      case 2:
        return _savedController;
      default:
        return _recipesController;
    }
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _recipesController?.removeListener(_onContentChanged);
    _recipesController?.dispose();
    _likedController?.removeListener(_onContentChanged);
    _likedController?.dispose();
    _savedController?.removeListener(_onContentChanged);
    _savedController?.dispose();
    _streakController?.removeListener(_onContentChanged);
    _streakController?.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    final ctrl = StreakController(userApi: UserApi(widget.apiClient));
    _streakController = ctrl;
    ctrl.addListener(_onContentChanged);
    await ctrl.load();
  }

  Future<void> _loadOwnProfile() async {
    final currentUsername = widget.auth.me?["username"]?.toString();
    if (currentUsername == null) return;
    try {
      final profile =
          await UserApi(widget.apiClient).getUserProfile(currentUsername);
      setState(() => _userProfile = profile);
    } catch (_) {}
  }

  Future<void> _refreshProfile() async {
    if (_isSelf) {
      await widget.auth.bootstrap();
      await _loadOwnProfile();
    } else {
      await _loadUserProfile();
    }
    await _recipesController?.refresh();
    if (_isSelf) {
      if (_likedController!.items.isNotEmpty) await _likedController!.refresh();
      if (_savedController!.items.isNotEmpty) await _savedController!.refresh();
    }
  }

  Future<void> _loadUserProfile() async {
    if (widget.username == null) return;
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });
    try {
      final profile =
          await UserApi(widget.apiClient).getUserProfile(widget.username!);
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

  Future<void> _toggleFollow() async {
    if (widget.username == null || _userProfile == null) return;
    if (!await checkEmailVerified(context, widget.auth)) return;

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
        await userApi.followUser(widget.username!);
        AnalyticsService().logFollow(widget.username!);
      } else {
        await userApi.unfollowUser(widget.username!);
        AnalyticsService().logUnfollow(widget.username!);
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
      if (mounted) {
        if (e is ApiException &&
            e.statusCode == 403 &&
            e.details is Map &&
            (e.details as Map)['code'] == 'EMAIL_UNVERIFIED') {
          await checkEmailVerified(context, widget.auth);
        } else {
          ErrorUtils.showError(context, e);
        }
      }
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final croppedFile = await ImageCropScreen.show(
        context,
        File(image.path),
        aspectRatio: 1.0,
      );
      if (croppedFile == null || !mounted) return;

      setState(() => _isUploading = true);

      final compressedFile = await ImageUtils.compressAvatar(croppedFile);
      final fileToUpload = compressedFile ?? croppedFile;

      await AuthApi(widget.apiClient).uploadAvatar(fileToUpload);
      await widget.auth.bootstrap();

      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          AppLocalizations.of(context)?.avatarUpdatedSuccessfully ??
              "Avatar updated successfully",
        );
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAvatarMenu(BuildContext context, String? avatarUrl) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(builder: (context) {
                final localizations = AppLocalizations.of(context);
                if (avatarUrl == null || avatarUrl.isEmpty) {
                  return ListTile(
                    leading: const Icon(Icons.add_photo_alternate_outlined),
                    title: Text(localizations?.addAvatar ?? "Add Avatar"),
                    onTap: () {
                      Navigator.of(context).pop();
                      _uploadAvatar();
                    },
                  );
                }
                return Column(children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(localizations?.updateAvatar ?? "Update Avatar"),
                    onTap: () {
                      Navigator.of(context).pop();
                      _uploadAvatar();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    title: Text(
                      localizations?.deleteAvatar ?? "Delete Avatar",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteAvatar();
                    },
                  ),
                ]);
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.deleteAvatar ?? "Delete Avatar"),
        content: Text(localizations?.areYouSureDeleteAvatar ??
            "Are you sure you want to remove your avatar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.delete ?? "Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      setState(() => _isDeleting = true);
      await AuthApi(widget.apiClient).deleteAvatar();
      await widget.auth.bootstrap();
      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          AppLocalizations.of(context)?.avatarRemovedSuccessfully ??
              "Avatar removed successfully",
        );
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showCoverPhotoMenu(BuildContext context) {
    final hasCover = _userProfile?.coverPhotoUrl != null;
    final localizations = AppLocalizations.of(context);
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(hasCover
                    ? (localizations?.changeCoverPhoto ?? "Change cover photo")
                    : (localizations?.addCoverPhoto ?? "Add cover photo")),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickCoverPhoto(context);
                },
              ),
              if (hasCover)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: Theme.of(ctx).colorScheme.error),
                  title: Text(
                    localizations?.removeCoverPhoto ?? "Remove cover photo",
                    style:
                        TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeCoverPhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCoverPhoto(BuildContext parentContext) async {
    final allItems = _recipesController?.items ?? [];
    final withImages =
        allItems.where((r) => r.images.isNotEmpty).toList();

    if (!mounted) return;

    final localizations = AppLocalizations.of(parentContext);

    if (withImages.isEmpty) {
      ErrorUtils.showError(
        parentContext,
        localizations?.noRecipesForCover ?? "Upload a recipe with a photo first",
      );
      return;
    }

    // Collect all images from all recipes (first image per recipe)
    final imageOptions = withImages
        .map((r) => r.images.first)
        .toList();

    final selected = await showAppBottomSheet<String>(
      context: parentContext,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                localizations?.selectCoverPhotoTitle ?? "Select cover photo",
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(4),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: imageOptions.length,
                itemBuilder: (_, i) {
                  final img = imageOptions[i];
                  final isActive =
                      img.url == _userProfile?.coverPhotoUrl;
                  return GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(img.url),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RecipeImageWidget(
                          imageUrl: img.url,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          cacheHeight: 300,
                        ),
                        if (isActive)
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: const Icon(Icons.check_circle,
                                color: Colors.white, size: 28),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _applySetCoverPhoto(selected);
  }

  Future<void> _applySetCoverPhoto(String imageUrl) async {
    setState(() => _isSettingCover = true);
    try {
      await UserApi(widget.apiClient).setCoverPhoto(imageUrl);
      setState(() {
        _userProfile = _userProfile?.copyWith(coverPhotoUrl: imageUrl);
      });
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          localizations?.coverPhotoUpdated ?? "Cover photo updated",
        );
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSettingCover = false);
    }
  }

  Future<void> _removeCoverPhoto() async {
    setState(() => _isSettingCover = true);
    try {
      await UserApi(widget.apiClient).setCoverPhoto(null);
      setState(() {
        _userProfile = _userProfile?.copyWith(coverPhotoUrl: null);
      });
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          localizations?.coverPhotoRemoved ?? "Cover photo removed",
        );
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSettingCover = false);
    }
  }

  Future<void> _handleBlockUser() async {
    final profile = _userProfile;
    if (profile == null) return;

    final isCurrentlyBlocked = profile.viewerIsBlocked;

    if (!isCurrentlyBlocked) {
      final localizations = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(localizations?.blockUser ?? "Block User",
              style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final profile = _userProfile;
    if (profile == null) return;
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
    if (!_isSelf && _isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isSelf && (_error != null || _userProfile == null)) {
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
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: Text(AppLocalizations.of(context)?.retry ?? "Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSelf && widget.auth.me == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)?.profile ?? "Profile"),
        ),
        body: Center(
          child: Text(
              AppLocalizations.of(context)?.notLoggedIn ?? "Not logged in"),
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

    // Resolve data for self vs other
    final String displayName;
    final String username;
    final String? avatarUrl;
    final String? email;
    final String? bio;
    final int followersCount;
    final int followingCount;
    final int totalLikes;

    if (_isSelf) {
      final user = widget.auth.me!;
      username = user["username"]?.toString() ?? "";
      displayName = user["display_name"]?.toString() ?? username;
      avatarUrl = user["avatar_url"]?.toString();
      email = user["email"]?.toString();
      bio = _userProfile?.bio;
      followersCount = _userProfile?.followersCount ?? 0;
      followingCount = _userProfile?.followingCount ?? 0;
      totalLikes = _userProfile?.totalLikesCount ?? 0;
    } else {
      final profile = _userProfile!;
      username = profile.username;
      displayName = profile.displayName ?? profile.username;
      avatarUrl = profile.avatarUrl;
      email = null;
      bio = profile.bio;
      followersCount = profile.followersCount;
      followingCount = profile.followingCount;
      totalLikes = profile.totalLikesCount;
    }

    final normalizedAvatarUrl =
        (avatarUrl == null || avatarUrl.isEmpty || avatarUrl == "null")
            ? null
            : avatarUrl;

    final coverImageUrl = _userProfile?.coverPhotoUrl;

    final streak = _streakController?.currentStreak ?? 0;
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
                    if (!_isSelf &&
                        widget.auth.isLoggedIn &&
                        !(_userProfile?.isViewer ?? true))
                      _TopBarButton(
                        icon: Icons.more_vert,
                        onTap: () => _showMoreMenu(context),
                      ),
                  ],
                ),
              ),
              // Cover edit button (self only)
              if (_isSelf)
                Positioned(
                  bottom: avatarOverflow + 10,
                  right: 14,
                  child: GestureDetector(
                    onTap: _isSettingCover
                        ? null
                        : () => _showCoverPhotoMenu(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1.5),
                      ),
                      child: _isSettingCover
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)),
                            )
                          : const Icon(Icons.photo_camera,
                              size: 17, color: Colors.white),
                    ),
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

        // ── Name, stats, actions, tabs ───────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + streak chip
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
                  if (_isSelf && streak >= 2) ...[
                    const SizedBox(width: 8),
                    _StreakChip(
                      streak: streak,
                      loaded: _streakController?.loaded == true,
                    ),
                  ],
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
              // Email (self only)
              if (_isSelf && email != null && email.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.mail_outline,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
              // Bio (other only)
              if (!_isSelf && bio != null && bio.isNotEmpty) ...[
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
                followersCount: followersCount,
                followingCount: followingCount,
                totalLikes: totalLikes,
                username: username,
                auth: widget.auth,
                apiClient: widget.apiClient,
                shoppingListController: widget.shoppingListController,
              ),
              const SizedBox(height: 14),
              // Action row
              if (_isSelf)
                _SelfActionRow(
                  onEditProfile: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                          auth: widget.auth,
                          apiClient: widget.apiClient,
                        ),
                      ),
                    );
                    if (result == true) _refreshProfile();
                  },
                )
              else
                _OtherActionRow(
                  isFollowing: _isFollowing,
                  isLoggedIn: widget.auth.isLoggedIn,
                  onFollow: _toggleFollow,
                ),
              // Ban banners
              if (_isSelf) ...[
                const SizedBox(height: 8),
                _buildBanBanners(context),
              ],
              // Tabs (self only)
              if (_isSelf) ...[
                const SizedBox(height: 18),
                _buildTabBar(context),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
        ),
        // Camera button (self only)
        if (_isSelf)
          Positioned(
            right: -4,
            bottom: -4,
            child: GestureDetector(
              onTap: _isUploading || _isDeleting
                  ? null
                  : () => _showAvatarMenu(context, avatarUrl),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF53B175),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
                child: const Icon(Icons.photo_camera,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        // Upload/delete loading overlay
        if (_isSelf && (_isUploading || _isDeleting))
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final tabs = [
      (Icons.restaurant_menu_outlined, Icons.restaurant_menu, localizations?.recipes ?? "Recipes"),
      (Icons.favorite_border, Icons.favorite, localizations?.profileTabLiked ?? "Liked"),
      (Icons.bookmark_border, Icons.bookmark, localizations?.profileTabSaved ?? "Saved"),
    ];

    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = (_tabController?.index ?? 0) == i;
        final outlinedIcon = tabs[i].$1;
        final filledIcon = tabs[i].$2;
        final label = tabs[i].$3;

        return Expanded(
          child: GestureDetector(
            onTap: () => _tabController?.animateTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? null
                    : Border.all(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? filledIcon : outlinedIcon,
                    size: 16,
                    color: isActive
                        ? theme.colorScheme.surface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? theme.colorScheme.surface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  ),
                ],
              ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBanBanners(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.auth.isPermanentlyBanned) {
      return _BanBanner(
        message: localizations?.accountPermanentlyBannedMessage ??
            "Your account has been permanently suspended.",
        color: theme.colorScheme.error,
      );
    }
    if (widget.auth.isSoftBanned) {
      return _BanBanner(
        message: localizations?.accountSoftBannedUntil(
                formatDate(context, widget.auth.softBannedUntil!)) ??
            "Your account is temporarily suspended.",
        color: theme.colorScheme.error,
      );
    }
    if (widget.auth.violationCount == 2) {
      return _BanBanner(
        message: localizations?.violationWarning2 ??
            "Warning: 1 more violation will result in a 7-day suspension",
        color: Colors.orange,
      );
    }
    if (widget.auth.violationCount == 5) {
      return _BanBanner(
        message: localizations?.violationWarning5 ??
            "Warning: 1 more violation will result in a permanent ban",
        color: theme.colorScheme.error,
      );
    }
    return const SizedBox.shrink();
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    final controller = _activeController;
    if (controller == null) return [];

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
      final String title;
      final String description;
      final IconData icon;
      if (_isSelf) {
        switch (_tabController?.index ?? 0) {
          case 1:
            title = localizations?.noLikedRecipesYet ?? "No liked recipes yet";
            description = localizations?.likedRecipesEmptyDescription ?? "Recipes you like will appear here";
            icon = Icons.favorite_border;
            break;
          case 2:
            title = localizations?.noSavedRecipes ?? "No saved recipes";
            description = localizations?.startBookmarkingRecipes ?? "Recipes you save will appear here";
            icon = Icons.bookmark_border;
            break;
          default:
            title = localizations?.noRecipesYet ?? "No recipes yet";
            description = localizations?.createYourFirstRecipe ?? "Create your first recipe!";
            icon = Icons.restaurant_menu_outlined;
        }
      } else {
        title = localizations?.noRecipesYet ?? "No recipes yet";
        description = localizations?.userNoRecipesYet ?? "This user hasn't created any recipes yet";
        icon = Icons.restaurant_menu_outlined;
      }
      return [
        SliverFillRemaining(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
                icon: icon, title: title, description: description),
          ),
        ),
      ];
    }

    final recipeCount = (_isSelf && (_tabController?.index ?? 0) == 0)
        ? (_userProfile?.recipesCount ?? controller.items.length)
        : controller.items.length;

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
                      Theme.of(context).colorScheme.surfaceContainerHighest,
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
        child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak, required this.loaded});

  final int streak;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: loaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB347), Color(0xFFE55A2B)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59E55A2B),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          AppLocalizations.of(context)?.streakDaysLabel(streak) ?? "🔥 $streak-day streak",
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
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
        color: theme.colorScheme.surface,
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

class _SelfActionRow extends StatelessWidget {
  const _SelfActionRow({required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: onEditProfile,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(
            AppLocalizations.of(context)?.editProfile ?? "Edit Profile"),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _OtherActionRow extends StatelessWidget {
  const _OtherActionRow({
    required this.isFollowing,
    required this.isLoggedIn,
    required this.onFollow,
  });

  final bool isFollowing;
  final bool isLoggedIn;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return const SizedBox.shrink();

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
              ? theme.colorScheme.surfaceContainerHighest
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

class _BanBanner extends StatelessWidget {
  const _BanBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
