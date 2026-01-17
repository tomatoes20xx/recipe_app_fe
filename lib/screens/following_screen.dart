import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../config.dart";
import "../users/following_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "profile_screen.dart";

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    super.key,
    required this.username,
    required this.apiClient,
    required this.auth,
  });

  final String username;
  final ApiClient apiClient;
  final AuthController auth;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  late final FollowingController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = FollowingController(
      userApi: UserApi(widget.apiClient),
      username: widget.username,
    );
    controller.addListener(_onChanged);
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >
              _scrollController.position.maxScrollExtent - 300) {
        controller.loadMore();
      }
    });
    controller.loadInitial();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(UserSearchResult user) async {
    final oldFollowing = user.viewerIsFollowing;
    final newFollowing = !oldFollowing;

    try {
      final userApi = UserApi(widget.apiClient);
      if (newFollowing) {
        await userApi.followUser(user.username);
      } else {
        await userApi.unfollowUser(user.username);
      }
      // Refresh the list to update follow status
      controller.refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to ${newFollowing ? 'follow' : 'unfollow'}: $e")),
        );
      }
    }
  }

  String _buildImageUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    return "${Config.apiBaseUrl}$relativeUrl";
  }

  Widget _buildUserAvatar(BuildContext context, String? avatarUrl, String username, {double radius = 20}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primary,
        backgroundImage: NetworkImage(_buildImageUrl(avatarUrl)),
        onBackgroundImageError: (exception, stackTrace) {
          // Image failed to load, will show child as fallback
        },
        child: null,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: username.isNotEmpty
          ? Text(
              username[0].toUpperCase(),
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Icon(
              Icons.person_outline_rounded,
              size: radius,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Following"),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.isPrivate) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "Private",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "This user's following list is private",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (controller.error != null && controller.items.isEmpty) {
      return Center(
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
              "Error",
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
      );
    }

    if (controller.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "Not following anyone",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "This user isn't following anyone yet",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      cacheExtent: 500,
      itemCount: controller.items.length + (controller.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= controller.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = controller.items[index];

        return RepaintBoundary(
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _buildUserAvatar(
                context,
                user.avatarUrl,
                user.username,
                radius: 24,
              ),
              title: Text(
                user.displayName ?? user.username,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                "@${user.username}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
              trailing: user.viewerIsMe
                  ? null
                  : FollowButton(
                      isFollowing: user.viewerIsFollowing,
                      onTap: () => _toggleFollow(user),
                    ),
              onTap: () {
                if (user.viewerIsMe) {
                  // Navigate to own profile
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        auth: widget.auth,
                        apiClient: widget.apiClient,
                      ),
                    ),
                  );
                } else {
                  // Navigate to other user's profile
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        auth: widget.auth,
                        apiClient: widget.apiClient,
                        username: user.username,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}
