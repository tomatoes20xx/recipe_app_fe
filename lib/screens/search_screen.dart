import "dart:async";

import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../recipes/recipe_detail_screen.dart";
import "../search/search_api.dart";
import "../search/search_controller.dart" as search;
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_search_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "profile_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.apiClient,
    this.auth,
  });

  final ApiClient apiClient;
  final AuthController? auth;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late final search.RecipeSearchController recipeSearchController;
  late final UserSearchController userSearchController;
  late final TabController _tabController;
  final TextEditingController _searchTextController = TextEditingController();
  final ScrollController _recipeScrollController = ScrollController();
  final ScrollController _userScrollController = ScrollController();
  
  Timer? _debounceTimer;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    recipeSearchController = search.RecipeSearchController(
      searchApi: SearchApi(widget.apiClient),
    );
    recipeSearchController.addListener(_onRecipeSearchChanged);

    userSearchController = UserSearchController(
      userApi: UserApi(widget.apiClient),
    );
    userSearchController.addListener(_onUserSearchChanged);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });

    _recipeScrollController.addListener(() {
      if (_recipeScrollController.hasClients &&
          _recipeScrollController.position.pixels > 
          _recipeScrollController.position.maxScrollExtent - 300) {
        recipeSearchController.loadMore();
      }
    });

    _userScrollController.addListener(() {
      if (_userScrollController.hasClients &&
          _userScrollController.position.pixels > 
          _userScrollController.position.maxScrollExtent - 300) {
        userSearchController.loadMore();
      }
    });
  }

  void _onRecipeSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onUserSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleFollowToggle(UserSearchResult user) async {
    final oldFollowing = user.viewerIsFollowing;
    final newFollowing = !oldFollowing;

    try {
      await userSearchController.toggleFollow(user.username);
      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          newFollowing ? "Now following ${user.username}" : "Unfollowed ${user.username}",
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchTextController.dispose();
    _recipeScrollController.dispose();
    _userScrollController.dispose();
    _tabController.dispose();
    recipeSearchController.removeListener(_onRecipeSearchChanged);
    recipeSearchController.dispose();
    userSearchController.removeListener(_onUserSearchChanged);
    userSearchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // If query is empty, clear immediately
    if (query.trim().isEmpty) {
      recipeSearchController.clear();
      userSearchController.clear();
      return;
    }
    
    // Debounce search by 500ms to reduce API calls
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_currentTab == 0) {
        recipeSearchController.search(query);
      } else {
        userSearchController.search(query);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Recipes", icon: Icon(Icons.restaurant_menu)),
            Tab(text: "Users", icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchTextController,
              decoration: InputDecoration(
                hintText: _currentTab == 0
                    ? "Search recipes, ingredients, tags..."
                    : "Search users by username...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTextController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchTextController.clear();
                          recipeSearchController.clear();
                          userSearchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                // Update suffix icon immediately for better UX
                setState(() {});
                // Debounce the actual search
                _performSearch(value);
              },
              onSubmitted: (value) {
                // Cancel debounce and search immediately on submit
                _debounceTimer?.cancel();
                if (value.trim().isNotEmpty) {
                  if (_currentTab == 0) {
                    recipeSearchController.search(value);
                  } else {
                    userSearchController.search(value);
                  }
                } else {
                  recipeSearchController.clear();
                  userSearchController.clear();
                }
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecipeResults(),
                _buildUserResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeResults() {
    if (recipeSearchController.currentQuery == null || recipeSearchController.currentQuery!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "Search for recipes",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try searching for ingredients, tags, or recipe names",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
            ),
          ],
        ),
      );
    }

    if (recipeSearchController.isLoading && recipeSearchController.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recipeSearchController.error != null) {
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
              ErrorUtils.getUserFriendlyMessage(recipeSearchController.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(recipeSearchController.currentQuery!),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (recipeSearchController.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "No results found",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search query",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _recipeScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      cacheExtent: 500, // Cache 500px worth of items off-screen for smoother scrolling
      itemCount: recipeSearchController.items.length + (recipeSearchController.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= recipeSearchController.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = recipeSearchController.items[index];
        final date = formatDate(item.createdAt);

        return RepaintBoundary(
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipeId: item.id,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              buildUserAvatar(context, item.authorAvatarUrl, item.authorUsername),
                              const SizedBox(width: 6),
                              Text(
                                "@${item.authorUsername} • $date",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserResults() {
    if (userSearchController.currentQuery == null || userSearchController.currentQuery!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "Search for users",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try searching by username",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
            ),
          ],
        ),
      );
    }

    if (userSearchController.isLoading && userSearchController.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userSearchController.error != null) {
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
              ErrorUtils.getUserFriendlyMessage(userSearchController.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(userSearchController.currentQuery!),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (userSearchController.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "No users found",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search query",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _userScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      cacheExtent: 500, // Cache 500px worth of items off-screen for smoother scrolling
      itemCount: userSearchController.items.length + (userSearchController.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= userSearchController.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = userSearchController.items[index];
        final isCurrentUser = user.viewerIsMe;

        return RepaintBoundary(
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (isCurrentUser) {
                  // Navigate to own profile
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        auth: widget.auth!,
                        apiClient: widget.apiClient,
                      ),
                    ),
                  );
                } else if (widget.auth?.isLoggedIn == true) {
                  // Navigate to other user's profile
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        auth: widget.auth!,
                        apiClient: widget.apiClient,
                        username: user.username,
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    buildUserAvatar(context, user.avatarUrl, user.username, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? user.username,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "@${user.username}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.auth?.isLoggedIn == true && !isCurrentUser)
                      FollowButton(
                        isFollowing: user.viewerIsFollowing,
                        onTap: () => _handleFollowToggle(user),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
