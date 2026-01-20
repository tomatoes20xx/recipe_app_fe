import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../api/api_client.dart";
import "../analytics/analytics_api.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../search/search_api.dart";
import "../search/search_controller.dart" as search;
import "../search/search_filters.dart";
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

class _SearchScreenState extends State<SearchScreen> {
  late final AnalyticsApi analyticsApi;
  late final search.RecipeSearchController recipeSearchController;
  late final UserSearchController userSearchController;
  final TextEditingController _searchTextController = TextEditingController();
  final ScrollController _recipeScrollController = ScrollController();
  final ScrollController _userScrollController = ScrollController();
  
  Timer? _debounceTimer;
  bool _isRecipeSearch = true; // true for recipes, false for users

  @override
  void initState() {
    super.initState();
    analyticsApi = AnalyticsApi(widget.apiClient);
    recipeSearchController = search.RecipeSearchController(
      searchApi: SearchApi(widget.apiClient),
    );
    recipeSearchController.addListener(_onRecipeSearchChanged);

    userSearchController = UserSearchController(
      userApi: UserApi(widget.apiClient),
    );
    userSearchController.addListener(_onUserSearchChanged);

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
    recipeSearchController.removeListener(_onRecipeSearchChanged);
    recipeSearchController.dispose();
    userSearchController.removeListener(_onUserSearchChanged);
    userSearchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // If query is empty and no filters, clear immediately
    if (query.trim().isEmpty && !recipeSearchController.filters.hasActiveFilters) {
      recipeSearchController.clear();
      userSearchController.clear();
      return;
    }
    
    // Track search query (fire-and-forget)
    if (query.trim().isNotEmpty) {
      final filters = recipeSearchController.filters;
      final filterData = <String, dynamic>{};
      if (filters.cuisine != null && filters.cuisine!.isNotEmpty) {
        filterData["cuisine"] = filters.cuisine;
      }
      if (filters.tags.isNotEmpty) {
        filterData["tags"] = filters.tags;
      }
      if (filters.ingredients.isNotEmpty) {
        filterData["ingredients"] = filters.ingredients;
      }
      if (filters.cookingTimeMin != null) {
        filterData["cooking_time_min"] = filters.cookingTimeMin;
      }
      if (filters.cookingTimeMax != null) {
        filterData["cooking_time_max"] = filters.cookingTimeMax;
      }
      if (filters.difficulty != null && filters.difficulty!.isNotEmpty) {
        filterData["difficulty"] = filters.difficulty;
      }
      
      analyticsApi.trackSearch(
        query: query.trim(),
        filters: filterData.isEmpty ? null : filterData,
      );
    }
    
    // Debounce search by 500ms to reduce API calls
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isRecipeSearch) {
        // Update query in filters and search
        final updatedFilters = recipeSearchController.filters.copyWith(
          query: query.trim().isEmpty ? null : query.trim(),
        );
        recipeSearchController.search(filters: updatedFilters);
      } else {
        userSearchController.search(query);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchTextController,
            autofocus: false,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: _isRecipeSearch
                  ? (localizations?.searchRecipes ?? "Search recipes...")
                  : (localizations?.searchUsers ?? "Search users..."),
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clear button (appears first, to the left)
                  if (_searchTextController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        _searchTextController.clear();
                        recipeSearchController.clear();
                        userSearchController.clear();
                        setState(() {});
                      },
                    ),
                  // Search type toggle - Single button with both icons, active one highlighted (always rightmost)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 18,
                            color: _isRecipeSearch
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.people,
                            size: 18,
                            color: !_isRecipeSearch
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ],
                      ),
                      onPressed: () {
                        setState(() {
                          _isRecipeSearch = !_isRecipeSearch;
                          // Clear search when switching modes
                          _searchTextController.clear();
                          recipeSearchController.clear();
                          userSearchController.clear();
                        });
                      },
                      tooltip: _isRecipeSearch 
                          ? (localizations?.switchToUsers ?? "Switch to Users")
                          : (localizations?.switchToRecipes ?? "Switch to Recipes"),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ],
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
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
              if (_isRecipeSearch) {
                final updatedFilters = recipeSearchController.filters.copyWith(
                  query: value.trim().isEmpty ? null : value.trim(),
                );
                recipeSearchController.search(filters: updatedFilters);
              } else {
                if (value.trim().isNotEmpty) {
                  userSearchController.search(value);
                } else {
                  userSearchController.clear();
                }
              }
            },
            textInputAction: TextInputAction.search,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter button (only shown for recipe search, positioned below search bar)
          if (_isRecipeSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.tune),
                      if (recipeSearchController.filters.hasActiveFilters)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: AppLocalizations.of(context)?.filters ?? "Filters",
                  onPressed: () => _showFilterBottomSheet(context),
                ),
              ),
            ),
          // Results
          Expanded(
            child: _isRecipeSearch ? _buildRecipeResults() : _buildUserResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeResults() {
    if (!recipeSearchController.filters.hasActiveFilters) {
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.searchRecipes?.replaceAll("...", "") ?? "Search for recipes",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                );
              },
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.tryDifferentSearch ?? "Try searching for ingredients, tags, or recipe names",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                );
              },
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ElevatedButton(
                  onPressed: () {
                    recipeSearchController.search(filters: recipeSearchController.filters);
                  },
                  child: Text(localizations?.retry ?? "Retry"),
                );
              },
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  _isRecipeSearch 
                    ? (localizations?.noRecipesFound ?? "No recipes found")
                    : (localizations?.noUsersFound ?? "No users found"),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                );
              },
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

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        filters: recipeSearchController.filters,
        onApply: (filters) {
          recipeSearchController.updateFilters(filters);
          recipeSearchController.search(filters: filters);
          
          // Track filter application
          final filterData = <String, dynamic>{};
          if (filters.cuisine != null && filters.cuisine!.isNotEmpty) {
            filterData["cuisine"] = filters.cuisine;
          }
          if (filters.tags.isNotEmpty) {
            filterData["tags"] = filters.tags;
          }
          if (filters.ingredients.isNotEmpty) {
            filterData["ingredients"] = filters.ingredients;
          }
          if (filters.cookingTimeMin != null) {
            filterData["cooking_time_min"] = filters.cookingTimeMin;
          }
          if (filters.cookingTimeMax != null) {
            filterData["cooking_time_max"] = filters.cookingTimeMax;
          }
          if (filters.difficulty != null && filters.difficulty!.isNotEmpty) {
            filterData["difficulty"] = filters.difficulty;
          }
          
          if (filterData.isNotEmpty) {
            analyticsApi.trackFilterApplied(filterData);
          }
          
          Navigator.of(context).pop();
        },
        onClear: () {
          // Clear filters but keep the sheet open
          recipeSearchController.clear();
        },
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.filters,
    required this.onApply,
    required this.onClear,
  });

  final RecipeSearchFilters filters;
  final ValueChanged<RecipeSearchFilters> onApply;
  final VoidCallback onClear;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}


class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late RecipeSearchFilters _currentFilters;
  final _cuisineController = TextEditingController();
  final _tagController = TextEditingController();
  final _ingredientController = TextEditingController();
  final _cookingTimeMinController = TextEditingController();
  final _cookingTimeMaxController = TextEditingController();
  final List<String> _selectedTags = [];
  final List<String> _selectedIngredients = [];
  String? _cookingTimeError;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.filters;
    _cuisineController.text = widget.filters.cuisine ?? "";
    _selectedTags.addAll(widget.filters.tags);
    _selectedIngredients.addAll(widget.filters.ingredients);
    _cookingTimeMinController.text = widget.filters.cookingTimeMin?.toString() ?? "";
    _cookingTimeMaxController.text = widget.filters.cookingTimeMax?.toString() ?? "";
  }

  void _clearAllFilters() {
    setState(() {
      _currentFilters = RecipeSearchFilters();
      _cuisineController.clear();
      _selectedTags.clear();
      _selectedIngredients.clear();
      _cookingTimeMinController.clear();
      _cookingTimeMaxController.clear();
      _cookingTimeError = null;
    });
    // Also clear the search controller
    widget.onClear();
  }

  @override
  void dispose() {
    _cuisineController.dispose();
    _tagController.dispose();
    _ingredientController.dispose();
    _cookingTimeMinController.dispose();
    _cookingTimeMaxController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    // Parse cooking time from controllers
    final cookingTimeMin = _cookingTimeMinController.text.trim().isEmpty
        ? null
        : int.tryParse(_cookingTimeMinController.text.trim());
    final cookingTimeMax = _cookingTimeMaxController.text.trim().isEmpty
        ? null
        : int.tryParse(_cookingTimeMaxController.text.trim());
    
    // Track filter application
    final filterData = <String, dynamic>{};
    if (_currentFilters.cuisine != null && _currentFilters.cuisine!.isNotEmpty) {
      filterData["cuisine"] = _currentFilters.cuisine;
    }
    if (_currentFilters.tags.isNotEmpty) {
      filterData["tags"] = _currentFilters.tags;
    }
    if (_currentFilters.ingredients.isNotEmpty) {
      filterData["ingredients"] = _currentFilters.ingredients;
    }
    if (cookingTimeMin != null) {
      filterData["cooking_time_min"] = cookingTimeMin;
    }
    if (cookingTimeMax != null) {
      filterData["cooking_time_max"] = cookingTimeMax;
    }
    if (_currentFilters.difficulty != null && _currentFilters.difficulty!.isNotEmpty) {
      filterData["difficulty"] = _currentFilters.difficulty;
    }
    
    if (filterData.isNotEmpty) {
      // Access analyticsApi from parent widget - need to pass it down
      // For now, we'll track it in the parent SearchScreen
    }

    // Validate cooking time: min should not be more than max (they can be equal)
    if (cookingTimeMin != null && cookingTimeMax != null && cookingTimeMin > cookingTimeMax) {
      setState(() {
        _cookingTimeError = "Minimum time cannot be greater than maximum time";
      });
      ErrorUtils.showError(context, "Minimum cooking time cannot be greater than maximum time");
      return;
    }

    // Clear error if validation passes
    setState(() {
      _cookingTimeError = null;
    });

    // Get the current query from the search controller (preserve it)
    final currentQuery = widget.filters.query;

    final filters = RecipeSearchFilters(
      query: currentQuery, // Preserve the search query
      cuisine: _cuisineController.text.trim().isEmpty ? null : _cuisineController.text.trim(),
      tags: _selectedTags,
      ingredients: _selectedIngredients,
      cookingTimeMin: cookingTimeMin,
      cookingTimeMax: cookingTimeMax,
      difficulty: _currentFilters.difficulty,
    );
    widget.onApply(filters);
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();
    if (ingredient.isNotEmpty && !_selectedIngredients.contains(ingredient)) {
      setState(() {
        _selectedIngredients.add(ingredient);
        _ingredientController.clear();
      });
    }
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _selectedIngredients.remove(ingredient);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.filters ?? "Filters",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return TextButton(
                        onPressed: _clearAllFilters,
                        child: Text(localizations?.clearAll ?? "Clear All"),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Filter content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Cuisine filter
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.cuisine ?? "Cuisine",
                        child: TextField(
                          controller: _cuisineController,
                          decoration: InputDecoration(
                            hintText: localizations?.cuisineExample ?? "e.g., Italian, Mexican, Asian",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.restaurant),
                      ),
                    ),
                  );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Tags filter
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.tags ?? "Tags",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tagController,
                                    decoration: InputDecoration(
                                      hintText: localizations?.addTag ?? "Add a tag",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.label_outline),
                                ),
                                onSubmitted: (_) => _addTag(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _addTag,
                              icon: const Icon(Icons.add_circle),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedTags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedTags.map((tag) {
                              return Chip(
                                label: Text(tag),
                                onDeleted: () => _removeTag(tag),
                                deleteIcon: const Icon(Icons.close, size: 18),
                              );
                            }).toList(),
                          ),
                          ],
                        ],
                      ),
                    );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Ingredients filter
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.ingredients ?? "Ingredients",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ingredientController,
                                    decoration: InputDecoration(
                                      hintText: localizations?.addTag?.replaceAll("tag", "ingredient") ?? "Add ingredient",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.shopping_cart_outlined),
                                ),
                                onSubmitted: (_) => _addIngredient(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _addIngredient,
                              icon: const Icon(Icons.add_circle),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedIngredients.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedIngredients.map((ingredient) {
                              return Chip(
                                label: Text(ingredient),
                                onDeleted: () => _removeIngredient(ingredient),
                                deleteIcon: const Icon(Icons.close, size: 18),
                              );
                            }).toList(),
                          ),
                          ],
                        ],
                      ),
                    );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Cooking time filter
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.cookingTimeMinutes ?? "Cooking Time (minutes)",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: localizations?.min ?? "Min",
                                      hintText: "0",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.timer_outlined),
                                ),
                                onChanged: (value) {
                                  // Clear error when user starts typing
                                  if (_cookingTimeError != null) {
                                    setState(() {
                                      _cookingTimeError = null;
                                    });
                                  }
                                  // Update is handled in _applyFilters, but we can update state for immediate feedback
                                  final min = value.trim().isEmpty ? null : int.tryParse(value.trim());
                                  setState(() {
                                    _currentFilters = _currentFilters.copyWith(
                                      cookingTimeMin: min,
                                    );
                                  });
                                  // Validate in real-time if both fields have values
                                  final max = _cookingTimeMaxController.text.trim().isEmpty
                                      ? null
                                      : int.tryParse(_cookingTimeMaxController.text.trim());
                                  if (min != null && max != null && min > max) {
                                    setState(() {
                                      _cookingTimeError = "Minimum time cannot be greater than maximum time";
                                    });
                                  }
                                },
                                controller: _cookingTimeMinController,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                    decoration: InputDecoration(
                                      labelText: localizations?.max ?? "Max",
                                      hintText: "120",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.timer),
                                ),
                                onChanged: (value) {
                                  // Clear error when user starts typing
                                  if (_cookingTimeError != null) {
                                    setState(() {
                                      _cookingTimeError = null;
                                    });
                                  }
                                  // Update is handled in _applyFilters, but we can update state for immediate feedback
                                  final max = value.trim().isEmpty ? null : int.tryParse(value.trim());
                                  setState(() {
                                    _currentFilters = _currentFilters.copyWith(
                                      cookingTimeMax: max,
                                    );
                                  });
                                  // Validate in real-time if both fields have values
                                  final min = _cookingTimeMinController.text.trim().isEmpty
                                      ? null
                                      : int.tryParse(_cookingTimeMinController.text.trim());
                                  if (min != null && max != null && min > max) {
                                    setState(() {
                                      _cookingTimeError = "Minimum time cannot be greater than maximum time";
                                    });
                                  }
                                },
                                controller: _cookingTimeMaxController,
                              ),
                            ),
                          ],
                        ),
                        if (_cookingTimeError != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              _cookingTimeError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Difficulty filter
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.difficulty ?? "Difficulty",
                        child: SegmentedButton<String?>(
                          segments: [
                            ButtonSegment(value: "easy", label: Text(localizations?.easy ?? "Easy")),
                            ButtonSegment(value: "medium", label: Text(localizations?.medium ?? "Medium")),
                            ButtonSegment(value: "hard", label: Text(localizations?.hard ?? "Hard")),
                          ],
                      selected: {_currentFilters.difficulty},
                      onSelectionChanged: (Set<String?> newSelection) {
                        setState(() {
                          _currentFilters = _currentFilters.copyWith(
                            difficulty: newSelection.firstOrNull,
                          );
                        });
                      },
                      multiSelectionEnabled: false,
                    ),
                  );
                    },
                  ),
                ],
              ),
            ),
            // Apply button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () {
                    final filters = RecipeSearchFilters(
                      query: _currentFilters.query,
                      cuisine: _cuisineController.text.trim().isEmpty ? null : _cuisineController.text.trim(),
                      tags: _selectedTags,
                      ingredients: _selectedIngredients,
                      cookingTimeMin: _currentFilters.cookingTimeMin,
                      cookingTimeMax: _currentFilters.cookingTimeMax,
                      difficulty: _currentFilters.difficulty,
                    );
                    if (!filters.isValid) {
                      ErrorUtils.showError(context, "Please add at least one filter or search query");
                      return;
                    }
                    _applyFilters();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text("Apply Filters"),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
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
