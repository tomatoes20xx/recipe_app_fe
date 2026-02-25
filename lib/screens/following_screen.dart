import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../shopping/shopping_list_controller.dart";
import "../users/following_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/empty_state_widget.dart";
import "profile_screen.dart";

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    super.key,
    required this.username,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
  });

  final String username;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;

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
      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          newFollowing
              ? (AppLocalizations.of(context)?.nowFollowingUser(user.username) ?? "Now following ${user.username}")
              : (AppLocalizations.of(context)?.unfollowedUser(user.username) ?? "Unfollowed ${user.username}"),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.followingTitle ?? "Following");
          },
        ),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.private ?? "Private",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                );
              },
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.thisUsersFollowingListIsPrivate ?? "This user's following list is private",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      );
    }

    if (controller.error != null && controller.items.isEmpty) {
      final localizations = AppLocalizations.of(context);
      final errorMessage = controller.error == "followingListPrivate"
          ? (localizations?.followingListPrivate ?? "This user's following list is private")
          : controller.error!;
      return ErrorStateWidget(
        message: errorMessage,
        onRetry: () => controller.loadInitial(),
      );
    }

    if (controller.items.isEmpty) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return EmptyStateWidget(
            icon: Icons.person_outline,
            title: localizations?.notFollowingAnyone ?? "Not following anyone",
            description: localizations?.thisUserIsntFollowingAnyoneYet ?? "This user isn't following anyone yet",
          );
        },
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: buildUserAvatar(
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        shoppingListController: widget.shoppingListController,
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
                        shoppingListController: widget.shoppingListController,
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
