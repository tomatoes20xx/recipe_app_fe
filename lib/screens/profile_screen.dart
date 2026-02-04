import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/empty_state_widget.dart";
import "followers_screen.dart";
import "following_screen.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    this.username,
  });

  final AuthController auth;
  final ApiClient apiClient;
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
  bool _isLoadingPrivacy = false;
  
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
      // Load own profile to get privacy settings
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
    // Always refresh recipes
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

  Future<void> _updatePrivacy({
    bool? followersPrivate,
    bool? followingPrivate,
  }) async {
    setState(() {
      _isLoadingPrivacy = true;
    });

    try {
      final userApi = UserApi(widget.apiClient);
      final updatedPrivacy = await userApi.updatePrivacy(
        followersPrivate: followersPrivate,
        followingPrivate: followingPrivate,
      );

      // Update local profile with new privacy settings
      if (_userProfile != null) {
        setState(() {
          _userProfile = _userProfile!.copyWith(privacy: updatedPrivacy);
          _isLoadingPrivacy = false;
        });
      }

      if (mounted) {
        ErrorUtils.showSuccess(context, "Privacy settings updated");
      }
    } catch (e) {
      setState(() {
        _isLoadingPrivacy = false;
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

      return Scaffold(
        appBar: AppBar(
          title: Text(_userProfile!.displayName ?? _userProfile!.username),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            controller: _recipesScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          buildUserAvatar(
                            context,
                            _userProfile!.avatarUrl,
                            _userProfile!.username,
                            radius: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userProfile!.displayName ?? _userProfile!.username,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "@${_userProfile!.username}",
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.auth.isLoggedIn && !_userProfile!.isViewer)
                            FollowButton(
                              isFollowing: _isFollowing,
                              onTap: _toggleFollow,
                            ),
                        ],
                      ),
                      if (_userProfile!.bio != null && _userProfile!.bio!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _userProfile!.bio!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowersScreen(
                                      username: _userProfile!.username,
                                      apiClient: widget.apiClient,
                                      auth: widget.auth,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return StatItem(
                                      label: localizations?.followers ?? "Followers",
                                      value: _userProfile!.followersCount.toString(),
                                      showChevron: true,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowingScreen(
                                      username: _userProfile!.username,
                                      apiClient: widget.apiClient,
                                      auth: widget.auth,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(context);
                                    return StatItem(
                                      label: localizations?.followingTitle ?? "Following",
                                      value: _userProfile!.followingCount.toString(),
                                      showChevron: true,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Recipes section
              ...(_recipesController != null ? [_buildRecipesSection(context)] : []),
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
    final displayName = user["displayName"]?.toString();
    final email = user["email"]?.toString() ?? "";
    final avatarUrl = user["avatar_url"]?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.profile ?? "Profile");
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: ListView(
          controller: _recipesScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _isUploading || _isDeleting
                              ? null
                              : () => _showAvatarMenu(context, avatarUrl),
                          child: Stack(
                            children: [
                            buildUserAvatar(context, avatarUrl, username, radius: 40),
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
                            // Pencil icon to indicate avatar is editable
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName ?? username,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "@$username",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FollowersScreen(
                                  username: username,
                                  apiClient: widget.apiClient,
                                  auth: widget.auth,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: StatItem(
                              label: "Followers",
                              value: _userProfile?.followersCount.toString() ?? "0",
                              showChevron: true,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FollowingScreen(
                                  username: username,
                                  apiClient: widget.apiClient,
                                  auth: widget.auth,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: StatItem(
                              label: "Following",
                              value: _userProfile?.followingCount.toString() ?? "0",
                              showChevron: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Privacy settings (only for own profile)
                  if (_userProfile?.isViewer == true && _userProfile?.privacy != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _PrivacySettings(
                      privacy: _userProfile!.privacy!,
                      onUpdate: _updatePrivacy,
                      isLoading: _isLoadingPrivacy,
                    ),
                  ],
                ],
              ),
            ),
            ),
            const SizedBox(height: 16),
            // Recipes section
            _buildRecipesSection(context),
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


class _PrivacySettings extends StatelessWidget {
  const _PrivacySettings({
    required this.privacy,
    required this.onUpdate,
    required this.isLoading,
  });

  final UserPrivacySettings privacy;
  final Future<void> Function({bool? followersPrivate, bool? followingPrivate}) onUpdate;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              "Privacy Settings",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text("Private Followers"),
          subtitle: const Text("Hide your followers list from others"),
          value: privacy.followersPrivate,
          onChanged: isLoading
              ? null
              : (value) {
                  onUpdate(followersPrivate: value);
                },
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text("Private Following"),
          subtitle: const Text("Hide your following list from others"),
          value: privacy.followingPrivate,
          onChanged: isLoading
              ? null
              : (value) {
                  onUpdate(followingPrivate: value);
                },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

