import "dart:io";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../feed/feed_models.dart";
import "../feed/feed_view_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/app_tokens.dart";
import "../theme/status_bar.dart";
import "../theme/theme_controller.dart";
import "../users/streak_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/common/profile_stats_card.dart";
import "../widgets/common/recipe_grid_tile.dart";
import "../widgets/common/skeleton_pill.dart";
import "../widgets/profile/profile_cover_header.dart";
import "edit_profile_screen.dart";
import "followers_screen.dart";
import "following_screen.dart";
import "image_crop_screen.dart";
import "liked_recipes_screen.dart";
import "my_recipes_screen.dart";
import "saved_recipes_screen.dart";
import "settings_screen.dart";
import "shared_recipes_screen.dart";
import "shared_shopping_lists_screen.dart";
import "shopping_list_screen.dart";

/// The Profile tab of the shell and the only screen for your own profile:
/// cover and avatar (both editable), stats, streak, library and your latest
/// recipes, with settings (and sign out) behind the gear. "See all" and the
/// recipes stat open [MyRecipesScreen]. Guests get a sign-up card instead of
/// the personal sections.
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

  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;
  bool _isSettingCover = false;

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

  /// Full recipe list and likes received. Coming back reloads counts and, if
  /// the recipe count changed, the preview (see [_load]).
  Future<void> _openMyRecipes() async {
    final username = _username;
    if (username == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MyRecipesScreen(
        auth: widget.auth,
        apiClient: widget.apiClient,
        shoppingListController: widget.shoppingListController,
        username: username,
      ),
    ));
    if (mounted) _load();
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
  // AVATAR + COVER PHOTO (moved here from ProfileScreen's self mode)
  // ─────────────────────────────────────────────────────────────

  /// Avatar and cover menus: a `sheet` bottom sheet with the sort sheet's
  /// drag handle.
  void _showMenuSheet(List<Widget> Function(BuildContext sheetContext) items) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),
              ...items(sheetContext),
            ],
          ),
        ),
      ),
    );
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

  void _showAvatarMenu(String? avatarUrl) {
    _showMenuSheet((context) {
      final localizations = AppLocalizations.of(context);
      if (avatarUrl == null || avatarUrl.isEmpty) {
        return [
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: Text(localizations?.addAvatar ?? "Add Avatar"),
            onTap: () {
              Navigator.of(context).pop();
              _uploadAvatar();
            },
          ),
        ];
      }
      return [
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(localizations?.updateAvatar ?? "Update Avatar"),
          onTap: () {
            Navigator.of(context).pop();
            _uploadAvatar();
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          title: Text(
            localizations?.deleteAvatar ?? "Delete Avatar",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () {
            Navigator.of(context).pop();
            _deleteAvatar();
          },
        ),
      ];
    });
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

  void _showCoverPhotoMenu() {
    final hasCover = _profile?.coverPhotoUrl != null;
    final parentContext = context;
    _showMenuSheet((ctx) {
      final localizations = AppLocalizations.of(ctx);
      return [
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(hasCover
              ? (localizations?.changeCoverPhoto ?? "Change cover photo")
              : (localizations?.addCoverPhoto ?? "Add cover photo")),
          onTap: () {
            Navigator.of(ctx).pop();
            _pickCoverPhoto(parentContext);
          },
        ),
        if (hasCover)
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
            title: Text(
              localizations?.removeCoverPhoto ?? "Remove cover photo",
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              _removeCoverPhoto();
            },
          ),
      ];
    });
  }

  Future<void> _pickCoverPhoto(BuildContext parentContext) async {
    final controller = _recipes;
    if (!mounted) return;

    final localizations = AppLocalizations.of(parentContext);

    final hasAnyImages =
        controller?.items.any((r) => r.images.isNotEmpty) ?? false;
    if (!hasAnyImages) {
      ErrorUtils.showError(
        parentContext,
        localizations?.noRecipesForCover ?? "Upload a recipe with a photo first",
      );
      return;
    }

    final selected = await showAppBottomSheet<String>(
      context: parentContext,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => _CoverPhotoGrid(
          scrollController: scrollCtrl,
          recipesController: controller,
          activeCoverUrl: _profile?.coverPhotoUrl,
          onSelected: (url) => Navigator.of(ctx).pop(url),
          title: localizations?.selectCoverPhotoTitle ?? "Select cover photo",
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
      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(coverPhotoUrl: imageUrl);
      });
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showSuccess(
        context,
        localizations?.coverPhotoUpdated ?? "Cover photo updated",
      );
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
      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(coverPhotoUrl: null);
      });
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showSuccess(
        context,
        localizations?.coverPhotoRemoved ?? "Cover photo removed",
      );
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSettingCover = false);
    }
  }

  /// Moved from ProfileScreen's self mode: same conditions and copy.
  /// Null when none applies.
  Widget? _buildBanBanner(BuildContext context) {
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
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  static const _gap = SizedBox(height: 24);

  /// Expanded cover height, status bar included.
  static const _coverHeight = 300.0;

  /// The collapsed header: name + gear, below the status bar.
  static const _whiteSpinner = SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return widget.auth.isLoggedIn ? _buildSignedIn(t, l) : _buildGuest(t, l);
  }

  /// Guests keep the plain layout: app bar (title + gear) and the sign-up
  /// card, below the status bar like the other tabs.
  Widget _buildGuest(AppTokens t, AppLocalizations? l) {
    return StatusBarInset(
      child: Material(
        color: t.bg,
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
                    _buildGuestCard(t, l),
                    _gap,
                    _buildLibrary(t, l, false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The cover is a pinned header that starts behind the status bar (the
  /// shell doesn't inset this tab) and collapses to a `bg` toolbar with the
  /// name and the gear.
  Widget _buildSignedIn(AppTokens t, AppLocalizations? l) {
    final banBanner = _buildBanBanner(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final collapsedHeight = safeTop + profileCoverToolbarHeight;

    return Material(
      color: t.bg,
      child: RefreshIndicator(
        color: t.brandInk,
        // Keeps the spinner below the status bar.
        edgeOffset: safeTop,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileCoverHeaderDelegate(
                minExtent: collapsedHeight,
                maxExtent: math.max(_coverHeight, collapsedHeight),
                builder: (context, collapse) => _buildCoverHeader(context, t, l, collapse, safeTop),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(
                children: [
                  if (banBanner != null) ...[
                    // The banner has an 8px top margin of its own: 16 in all.
                    const SizedBox(height: 8),
                    banBanner,
                  ],
                  const SizedBox(height: 16),
                  _buildStatsCard(l),
                  _gap,
                  _buildEditProfileButton(t, l),
                  _gap,
                  ListenableBuilder(
                    listenable: widget.streakController,
                    builder: (context, _) => widget.streakController.loaded
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildStreakCard(t, l),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _buildLibrary(t, l, true),
                  _gap,
                  _buildMyRecipes(t, l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Guest app bar.
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

  /// The shared cover header (widgets/profile/profile_cover_header.dart) with
  /// this tab's controls: camera + gear on the cover, the avatar menu, and
  /// "Add cover photo" while there is none.
  Widget _buildCoverHeader(
    BuildContext context,
    AppTokens t,
    AppLocalizations? l,
    double collapse,
    double safeTop,
  ) {
    final coverUrl = _profile?.coverPhotoUrl;
    final me = widget.auth.me;
    final username = me?["username"]?.toString() ?? "";
    final displayName = me?["display_name"]?.toString();
    final name = (displayName == null || displayName.isEmpty) ? username : displayName;

    return ProfileCoverHeader(
      collapse: collapse,
      expandedHeight: math.max(_coverHeight, safeTop + profileCoverToolbarHeight),
      topInset: safeTop,
      coverUrl: coverUrl,
      name: name,
      username: username,
      avatar: _buildCoverAvatar(l, username),
      // Waits for the profile, so it doesn't flash before an existing cover loads.
      coverOverlay: _profile != null && coverUrl == null ? _buildAddCoverPill(l) : null,
      coverActions: [
        ProfileCoverButton(
          tooltip: coverUrl != null
              ? (l?.changeCoverPhoto ?? "Change cover photo")
              : (l?.addCoverPhoto ?? "Add cover photo"),
          onPressed: _isSettingCover ? null : _showCoverPhotoMenu,
          icon: _isSettingCover ? _whiteSpinner : const Icon(Icons.photo_camera_outlined, size: 19),
        ),
        ProfileCoverButton(
          tooltip: l?.settings ?? "Settings",
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined, size: 20),
        ),
      ],
      toolbarActions: [
        IconButton(
          onPressed: _openSettings,
          tooltip: l?.settings ?? "Settings",
          icon: Icon(Icons.settings_outlined, color: t.ink),
        ),
      ],
    );
  }

  Widget _buildAddCoverPill(AppLocalizations? l) {
    final disabled = Colors.white.withValues(alpha: 0.5);
    return OutlinedButton.icon(
      onPressed: _isSettingCover ? null : _showCoverPhotoMenu,
      icon: const Icon(Icons.photo_camera_outlined, size: 18),
      label: Text(
        l?.addCoverPhoto ?? "Add cover photo",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        foregroundColor: Colors.white,
        iconColor: Colors.white,
        disabledForegroundColor: disabled,
        disabledIconColor: disabled,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// The avatar on the cover; tap → avatar menu. Camera badge, and a
  /// spinner on the photo while uploading or deleting.
  Widget _buildCoverAvatar(AppLocalizations? l, String username) {
    final avatarUrl = widget.auth.me?["avatar_url"]?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != "null";
    final avatarBusy = _isUploading || _isDeleting;
    const photoSize = ProfileCoverAvatar.photoSize;

    return Semantics(
      button: true,
      enabled: !avatarBusy,
      label: hasAvatar ? (l?.updateAvatar ?? "Update Avatar") : (l?.addAvatar ?? "Add Avatar"),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: avatarBusy ? null : () => _showAvatarMenu(hasAvatar ? avatarUrl : null),
        child: ProfileCoverAvatar(
          avatarUrl: avatarUrl,
          name: username,
          overlay: avatarBusy
              ? ClipOval(
                  child: Container(
                    width: photoSize,
                    height: photoSize,
                    color: Colors.black.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: _whiteSpinner,
                  ),
                )
              : null,
          badge: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTokens.of(context).fill,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.photo_camera, size: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(AppLocalizations? l) {
    final profile = _profile;
    final username = _username;
    return ProfileStatsCard(
      stats: [
        ProfileStat(
          value: profile?.recipesCount,
          label: l?.recipes ?? "Recipes",
          onTap: username == null ? null : _openMyRecipes,
        ),
        ProfileStat(
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
        ProfileStat(
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
    // Both come from the server, in the user's own timezone, so the dots
    // always match [n] and "today" flips at the user's midnight.
    final done = streak.streakDays;
    final today = streak.today;
    // Same check as today's dot, so the subtitle and the tick always agree.
    final doneToday = done.contains(today);
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
                      doneToday
                          ? (l?.streakDoneToday ?? "You cooked today. See you tomorrow!")
                          : (l?.streakKeepGoing ?? "Keep your streak going today"),
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
              // White text needs `primary` (fill is too light for it).
              backgroundColor: t.primary,
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
                icon: Icons.favorite_border_rounded,
                label: l?.likedRecipes ?? "Liked recipes",
                count: counts?.likedRecipes,
                loading: countsLoading,
                onTap: () => _requireAccountThen(AccountReason.like, (navigator) {
                  navigator.push(MaterialPageRoute(
                    builder: (_) => LikedRecipesScreen(
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
              child: RecipeGridRow(
                left: shown[i],
                right: i + 1 < shown.length ? shown[i + 1] : null,
                onTap: _openRecipe,
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
            if (total > 0)
              TextButton(
                onPressed: _openMyRecipes,
                style: TextButton.styleFrom(
                  foregroundColor: t.brandInk,
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: Text(l?.seeAll ?? "See all"),
              )
            else
              // Keeps the header row the same height without the button.
              const SizedBox(height: 48),
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
                const SkeletonPill(width: 48, height: 14),
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
                const SkeletonPill(width: 20, height: 14)
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

// Moved here unchanged from ProfileScreen's self mode.
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

// Moved here unchanged from ProfileScreen's self mode.
class _CoverPhotoGrid extends StatefulWidget {
  const _CoverPhotoGrid({
    required this.scrollController,
    required this.recipesController,
    required this.activeCoverUrl,
    required this.onSelected,
    required this.title,
  });

  final ScrollController scrollController;
  final UserRecipesController? recipesController;
  final String? activeCoverUrl;
  final ValueChanged<String> onSelected;
  final String title;

  @override
  State<_CoverPhotoGrid> createState() => _CoverPhotoGridState();
}

class _CoverPhotoGridState extends State<_CoverPhotoGrid> {
  @override
  void initState() {
    super.initState();
    widget.recipesController?.addListener(_onControllerUpdate);
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.recipesController?.removeListener(_onControllerUpdate);
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final ctrl = widget.scrollController;
    if (ctrl.position.pixels >= ctrl.position.maxScrollExtent - 300) {
      widget.recipesController?.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.recipesController;
    final imageOptions = (controller?.items ?? [])
        .where((r) => r.images.isNotEmpty)
        .map((r) => r.images.first)
        .toList();
    final isLoadingMore = controller?.isLoadingMore ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: sheetTopRadius,
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SheetHandle(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: imageOptions.length + (isLoadingMore ? 3 : 0),
              itemBuilder: (_, i) {
                if (i >= imageOptions.length) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final img = imageOptions[i];
                final isActive = img.url == widget.activeCoverUrl;
                return GestureDetector(
                  onTap: () => widget.onSelected(img.url),
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
    );
  }
}
