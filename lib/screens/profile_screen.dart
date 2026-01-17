import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:image/image.dart" as img;

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_models.dart";
import "../recipes/recipe_detail_screen.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/ui_utils.dart";

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
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to ${newFollowing ? 'follow' : 'unfollow'}: $e")),
        );
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

      // Compress the image before uploading (avatars are small, but compression helps)
      final compressedFile = await _compressImage(File(image.path));
      final fileToUpload = compressedFile ?? File(image.path);

      final authApi = AuthApi(widget.apiClient);
      await authApi.uploadAvatar(fileToUpload);
      
      // Refresh user data
      await widget.auth.bootstrap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload avatar: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// Compresses and resizes an image to reduce file size
  /// Max dimensions: 512x512 (for avatars), Quality: 85%
  Future<File?> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) return null;

      // For avatars, resize to 512x512 (square, center crop)
      const maxDimension = 512;
      
      // Calculate dimensions for square center crop
      int width = originalImage.width;
      int height = originalImage.height;
      int cropSize = width < height ? width : height;
      int offsetX = (width - cropSize) ~/ 2;
      int offsetY = (height - cropSize) ~/ 2;

      // Crop to square (center)
      final croppedImage = img.copyCrop(
        originalImage,
        x: offsetX,
        y: offsetY,
        width: cropSize,
        height: cropSize,
      );

      // Resize to 512x512
      final resizedImage = img.copyResize(
        croppedImage,
        width: maxDimension,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );

      // Convert to JPEG with 85% quality
      final jpegBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('${tempDir.path}/compressed_avatar_$timestamp.jpg');
      await compressedFile.writeAsBytes(jpegBytes);
      
      return compressedFile;
    } catch (e) {
      // If compression fails, return null to use original
      return null;
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
            if (avatarUrl == null || avatarUrl.isEmpty)
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text("Add Avatar"),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadAvatar();
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Update Avatar"),
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
                  "Delete Avatar",
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Avatar"),
        content: const Text("Are you sure you want to remove your avatar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar removed successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete avatar: $e")),
        );
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
          appBar: AppBar(title: const Text("Profile")),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (_error != null || _userProfile == null) {
        return Scaffold(
          appBar: AppBar(title: const Text("Profile")),
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
                ElevatedButton(
                  onPressed: _loadUserProfile,
                  child: const Text("Retry"),
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
          onRefresh: () async {
            await _loadUserProfile();
            await _recipesController?.refresh();
          },
          child: ListView(
            controller: _recipesScrollController,
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
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                          _StatItem(
                            label: "Recipes",
                            value: _userProfile!.recipesCount.toString(),
                          ),
                          _StatItem(
                            label: "Followers",
                            value: _userProfile!.followersCount.toString(),
                          ),
                          _StatItem(
                            label: "Following",
                            value: _userProfile!.followingCount.toString(),
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
        appBar: AppBar(title: const Text("Profile")),
        body: const Center(
          child: Text("Not logged in"),
        ),
      );
    }

    final username = user["username"]?.toString() ?? "Unknown";
    final displayName = user["displayName"]?.toString();
    final email = user["email"]?.toString() ?? "";
    final avatarUrl = user["avatar_url"]?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.auth.bootstrap();
          await _recipesController?.refresh();
        },
        child: ListView(
          controller: _recipesScrollController,
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
                                    color: Colors.black.withOpacity(0.5),
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
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
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
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                "Error loading recipes",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => controller.loadInitial(),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_menu_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  "No recipes yet",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.username == null
                      ? "Create your first recipe!"
                      : "This user hasn't created any recipes yet",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            "Recipes",
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
              child: _RecipeGridCard(
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
                buildImageUrl: buildImageUrl,
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


class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }
}

class _RecipeGridCard extends StatelessWidget {
  const _RecipeGridCard({
    required this.recipe,
    required this.onTap,
    required this.buildImageUrl,
  });

  final FeedItem recipe;
  final VoidCallback onTap;
  final String Function(String) buildImageUrl;

  @override
  Widget build(BuildContext context) {
    final firstImage = recipe.images.isNotEmpty ? recipe.images.first : null;
    final imageUrl = firstImage != null ? buildImageUrl(firstImage.url) : null;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (imageUrl != null)
            CachedNetworkImageWidget(
              imageUrl: imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            )
          else
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.restaurant_menu_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          // Gradient overlay for better text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Overlay content
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Stats row
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      recipe.likes.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chat_bubble,
                      size: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      recipe.comments.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: isFollowing
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      child: Text(
        isFollowing ? "Following" : "Follow",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isFollowing
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
