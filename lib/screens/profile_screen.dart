import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/empty_state_widget.dart";
import "edit_profile_screen.dart";
import "followers_screen.dart";
import "following_screen.dart";

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
  final String? username; // If provided, view this user's profile instead of current user

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;
  bool _isLoadingProfile = false;
  bool _isFollowing = false;
  UserProfile? _userProfile;
  String? _error;

  late final UserRecipesController? _recipesController;
  final ScrollController _recipesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Initialize recipes controller if viewing a user profile
    final targetUsername = widget.username ?? widget.auth.me?["username"]?.toString();
    if (targetUsername != null) {
      _recipesController = UserRecipesController(
        userApi: UserApi(widget.apiClient),
        username: targetUsername,
      );
      _recipesController!.addListener(_onRecipesChanged);
      _recipesScrollController.addListener(() {
        if (_recipesScrollController.hasClients &&
            _recipesScrollController.position.pixels > 
            _recipesScrollController.position.maxScrollExtent - 300) {
          _recipesController.loadMore();
        }
      });
      _recipesController.loadInitial();
    } else {
      _recipesController = null;
    }
    
    if (widget.username != null) {
      _loadUserProfile();
    } else {
      // Load own profile
      _loadOwnProfile();
    }
  }

  Future<void> _loadOwnProfile() async {
    final currentUsername = widget.auth.me?["username"]?.toString();
    if (currentUsername == null) return;

    try {
      final userApi = UserApi(widget.apiClient);
      final profile = await userApi.getUserProfile(currentUsername);

      setState(() {
        _userProfile = profile;
      });
    } catch (e) {
      // Silently fail - not critical for own profile
    }
  }

  /// Unified refresh method that works for both own profile and other users' profiles
  Future<void> _refreshProfile() async {
    if (widget.username != null) {
      // Other user's profile: load profile data
      await _loadUserProfile();
    } else {
      // Own profile: refresh auth data and load full profile
      await widget.auth.bootstrap();
      await _loadOwnProfile();
    }

    // Refresh recipes (username never changes, so no need to recreate controller)
    await _recipesController?.refresh();
  }

  void _onRecipesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recipesScrollController.dispose();
    _recipesController?.removeListener(_onRecipesChanged);
    _recipesController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (widget.username == null) return;

    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });

    try {
      final userApi = UserApi(widget.apiClient);
      final profile = await userApi.getUserProfile(widget.username!);
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
      } else {
        await userApi.unfollowUser(widget.username!);
      }
      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          newFollowing ? "Now following ${_userProfile!.username}" : "Unfollowed ${_userProfile!.username}",
        );
      }
    } catch (e) {
      // Rollback on error
      setState(() {
        _isFollowing = oldFollowing;
        _userProfile = _userProfile!.copyWith(
          viewerIsFollowing: oldFollowing,
          followersCount: _userProfile!.followersCount + (oldFollowing ? 1 : -1),
        );
      });
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      // Compress the image before uploading using shared utility
      final compressedFile = await ImageUtils.compressAvatar(File(image.path));
      final fileToUpload = compressedFile ?? File(image.path);

      final authApi = AuthApi(widget.apiClient);
      await authApi.uploadAvatar(fileToUpload);

      // Refresh user data
      await widget.auth.bootstrap();

      if (mounted) {
        ErrorUtils.showSuccess(context, "Avatar updated successfully");
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showAvatarMenu(BuildContext context, String? avatarUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) {
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
                } else {
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: Text(localizations?.updateAvatar ?? "Update Avatar"),
                        onTap: () {
                          Navigator.of(context).pop();
                          _uploadAvatar();
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          localizations?.deleteAvatar ?? "Delete Avatar",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _deleteAvatar();
                        },
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
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
        content: Text(localizations?.areYouSureDeleteAvatar ?? "Are you sure you want to remove your avatar?"),
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

      final authApi = AuthApi(widget.apiClient);
      await authApi.deleteAvatar();
      
      // Refresh user data
      await widget.auth.bootstrap();

      if (mounted) {
        ErrorUtils.showSuccess(context, "Avatar removed successfully");
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // If viewing another user's profile
    if (widget.username != null) {
      if (_isLoadingProfile) {
        return Scaffold(
          appBar: AppBar(
            title: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations?.profile ?? "Profile");
              },
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (_error != null || _userProfile == null) {
        return Scaffold(
          appBar: AppBar(
            title: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations?.profile ?? "Profile");
              },
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? "User not found",
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return ElevatedButton(
                      onPressed: _loadUserProfile,
                      child: Text(localizations?.retry ?? "Retry"),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }

      final theme = Theme.of(context);

      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: CustomScrollView(
            controller: _recipesScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Modern App Bar with gradient
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                backgroundColor: theme.colorScheme.surface,
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar with shadow
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: buildUserAvatar(
                                context,
                                _userProfile!.avatarUrl,
                                _userProfile!.username,
                                radius: 45,
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Name and username
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userProfile!.displayName ?? _userProfile!.username,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "@${_userProfile!.username}",
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Profile Content
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Follow button (if not viewing own profile)
                    if (widget.auth.isLoggedIn && !_userProfile!.isViewer) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _toggleFollow,
                          icon: Icon(_isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined),
                          label: Text(_isFollowing ? "Unfollow" : "Follow"),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primary,
                            foregroundColor: _isFollowing
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Bio (if exists)
                    if (_userProfile!.bio != null && _userProfile!.bio!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _userProfile!.bio!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Stats Card
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowersScreen(
                                        username: _userProfile!.username,
                                        apiClient: widget.apiClient,
                                        auth: widget.auth,
                                        shoppingListController: widget.shoppingListController,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  child: Builder(
                                    builder: (context) {
                                      final localizations = AppLocalizations.of(context);
                                      return Column(
                                        children: [
                                          Text(
                                            _userProfile!.followersCount.toString(),
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            localizations?.followers ?? "Followers",
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowingScreen(
                                        username: _userProfile!.username,
                                        apiClient: widget.apiClient,
                                        auth: widget.auth,
                                        shoppingListController: widget.shoppingListController,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  child: Builder(
                                    builder: (context) {
                                      final localizations = AppLocalizations.of(context);
                                      return Column(
                                        children: [
                                          Text(
                                            _userProfile!.followingCount.toString(),
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            localizations?.followingTitle ?? "Following",
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              child: Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(context);
                                  return Column(
                                    children: [
                                      Text(
                                        _userProfile!.totalLikesCount.toString(),
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        localizations?.totalLikes ?? "Total Likes",
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recipes section
                    if (_recipesController != null) _buildRecipesSection(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Viewing own profile
    final user = widget.auth.me;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(localizations?.profile ?? "Profile");
            },
          ),
        ),
        body: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Center(
              child: Text(localizations?.notLoggedIn ?? "Not logged in"),
            );
          },
        ),
      );
    }

    final username = user["username"]?.toString() ?? "Unknown";
    final displayName = user["display_name"]?.toString(); // Fixed: was "displayName", should be "display_name"
    final email = user["email"]?.toString() ?? "";
    final avatarUrl = user["avatar_url"]?.toString();

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: CustomScrollView(
          controller: _recipesScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Modern App Bar with gradient
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              backgroundColor: theme.colorScheme.surface,
              expandedHeight: 200,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                        theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar with edit functionality
                          GestureDetector(
                            onTap: _isUploading || _isDeleting
                                ? null
                                : () => _showAvatarMenu(context, avatarUrl),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  buildUserAvatar(context, avatarUrl, username, radius: 45),
                                  if (_isUploading || _isDeleting)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Edit icon
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.colorScheme.surface,
                                          width: 3,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Name and username
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName ?? username,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "@$username",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Profile Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              auth: widget.auth,
                              apiClient: widget.apiClient,
                            ),
                          ),
                        );
                        // Refresh profile if changes were made
                        if (result == true) {
                          _refreshProfile();
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(localizations?.editProfile ?? "Edit Profile");
                        },
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bio (if exists)
                  if (_userProfile?.bio != null && _userProfile!.bio!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _userProfile!.bio!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Email (if exists)
                  if (email.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              email,
                              style: theme.textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Stats Card
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowersScreen(
                                      username: username,
                                      apiClient: widget.apiClient,
                                      auth: widget.auth,
                                      shoppingListController: widget.shoppingListController,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                child: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return Column(
                                      children: [
                                        Text(
                                          _userProfile?.followersCount.toString() ?? "0",
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          localizations?.followers ?? "Followers",
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowingScreen(
                                      username: username,
                                      apiClient: widget.apiClient,
                                      auth: widget.auth,
                                      shoppingListController: widget.shoppingListController,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                child: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return Column(
                                      children: [
                                        Text(
                                          _userProfile?.followingCount.toString() ?? "0",
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          localizations?.followingTitle ?? "Following",
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            child: Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(context);
                                return Column(
                                  children: [
                                    Text(
                                      _userProfile?.totalLikesCount.toString() ?? "0",
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      localizations?.totalLikes ?? "Total Likes",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recipes section
                  _buildRecipesSection(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesSection(BuildContext context) {
    final controller = _recipesController;
    if (controller == null) return const SizedBox.shrink();
    
    // Get recipe count from profile if available, otherwise use controller items length
    final recipeCount = _userProfile?.recipesCount ?? controller.items.length;

    if (controller.isLoading && controller.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (controller.error != null && controller.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorStateWidget(
            message: controller.error!,
            onRetry: () => controller.loadInitial(),
          ),
        ),
      );
    }

    if (controller.items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.restaurant_menu_outlined,
        title: "No recipes yet",
        description: widget.username == null
            ? "Create your first recipe!"
            : "This user hasn't created any recipes yet",
        wrapInCard: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            "$recipeCount Recipes",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.75,
          ),
          itemCount: controller.items.length + (controller.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= controller.items.length) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final recipe = controller.items[index];
            return RepaintBoundary(
              child: RecipeGridCard(
                recipe: recipe,
                onTap: () {
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
                },
              ),
            );
          },
        ),
        if (controller.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}



