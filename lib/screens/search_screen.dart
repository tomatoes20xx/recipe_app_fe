import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../api/api_client.dart";
import "../analytics/analytics_api.dart";
import "../auth/auth_controller.dart";
import "../constants/cuisines.dart";
import "../constants/dietary_preferences.dart";
import "../constants/recipe_categories.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../search/search_api.dart";
import "../search/search_filters.dart";
import "../search/search_history_storage.dart";
import "../search/search_models.dart";
import "../search/unified_search_controller.dart";
import "../shopping/shopping_list_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/empty_state_widget.dart";
import "pantry_search_screen.dart";
import "profile_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.apiClient,
    required this.shoppingListController,
    this.auth,
    this.searchQuery,
  });

  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final AuthController? auth;
  final String? searchQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final AnalyticsApi analyticsApi;
  late final UnifiedSearchController searchController;
  late final UserApi userApi;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchTextController = TextEditingController();

  Timer? _debounceTimer;
  String? _lastSearchedQuery;

  @override
  void initState() {
    super.initState();
    analyticsApi = AnalyticsApi(widget.apiClient);
    userApi = UserApi(widget.apiClient);
    searchController = UnifiedSearchController(
      searchApi: SearchApi(widget.apiClient),
      userApi: userApi,
      historyStorage: SearchHistoryStorage(),
    );
    searchController.addListener(_onSearchChanged);
    searchController.loadRecentSearches();

    _scrollController.addListener(_onScroll);

    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _performSearch(widget.searchQuery!);
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _performSearch(widget.searchQuery ?? "");
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 300) {
      searchController.loadMoreRecipes();
    }
  }

  Future<void> _handleFollowToggle(UserSearchResult user) async {
    final newFollowing = !user.viewerIsFollowing;

    try {
      await searchController.toggleFollow(user.username);
      if (mounted) {
        ErrorUtils.showSuccess(
          context,
          newFollowing
              ? "Now following ${user.username}"
              : "Unfollowed ${user.username}",
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
    _scrollController.dispose();
    _searchTextController.dispose();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();

    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      _lastSearchedQuery = null;
      searchController.clear();
      return;
    }

    // Require at least 2 characters to search
    if (trimmedQuery.length < 2) {
      return;
    }

    // Avoid re-searching the same query
    if (trimmedQuery == _lastSearchedQuery) {
      return;
    }

    final filters = searchController.recipeFilters;
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
      query: trimmedQuery,
      filters: filterData.isEmpty ? null : filterData,
    );

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _lastSearchedQuery = trimmedQuery;
      searchController.search(trimmedQuery);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(localizations?.search ?? "Search"),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchTextController,
                  autofocus: false,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: localizations?.searchRecipes ?? "Search recipes, users...",
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    suffixIcon: _searchTextController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchTextController.clear();
                              searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) {
                    if (query.trim().isNotEmpty) {
                      _performSearch(query.trim());
                    }
                  },
                  onChanged: (value) {
                    setState(() {}); // Rebuild to show/hide clear button
                  },
                ),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          _buildFiltersButton(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (searchController.currentQuery == null ||
        searchController.currentQuery!.isEmpty) {
      return _buildRecentSearches();
    }

    if (searchController.isLoading &&
        searchController.users.isEmpty &&
        searchController.recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchController.error != null &&
        searchController.users.isEmpty &&
        searchController.recipes.isEmpty) {
      return ErrorStateWidget(
        message:
            ErrorUtils.getUserFriendlyMessage(searchController.error!, context),
        onRetry: () {
          searchController.search(searchController.currentQuery!);
        },
      );
    }

    return _buildGroupedResults();
  }

  Widget _buildRecentSearches() {
    final localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cook with What I Have card
          _CookWithIngredientsCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantrySearchScreen(
                    apiClient: widget.apiClient,
                    auth: widget.auth,
                    shoppingListController: widget.shoppingListController,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Recent searches section
          if (searchController.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations?.recentSearches ?? "Recent Searches",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
                GestureDetector(
                  onTap: () => searchController.clearHistory(),
                  child: Text(
                    localizations?.clearAll ?? "Clear All",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: searchController.recentSearches.map((query) {
                return InputChip(
                  label: Text(
                    query,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  avatar: Icon(
                    Icons.history,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  onDeleted: () => searchController.removeFromHistory(query),
                  onPressed: () {
                    _lastSearchedQuery = query;
                    searchController.search(query, saveToHistory: true);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupedResults() {
    final hasUsers = searchController.users.isNotEmpty;
    final hasRecipes = searchController.recipes.isNotEmpty;
    final localizations = AppLocalizations.of(context);

    if (!hasUsers && !hasRecipes) {
      return EmptyStateWidget(
        icon: Icons.search_off,
        title: localizations?.noResultsFound ?? "No results found",
        description:
            localizations?.tryDifferentSearch ?? "Try a different search query",
        titleStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
        descriptionStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (hasUsers) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              localizations?.users ?? "Users",
              showAction: searchController.usersHasMore,
              actionWidget: TextButton(
                onPressed: () => searchController.loadMoreUsers(),
                child: Text(localizations?.seeAll ?? "See all"),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= searchController.users.length) {
                  return searchController.isLoadingMoreUsers
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : null;
                }
                return _buildUserCard(searchController.users[index]);
              },
              childCount: searchController.users.length +
                  (searchController.isLoadingMoreUsers ? 1 : 0),
            ),
          ),
        ],
        if (hasRecipes) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              localizations?.recipes ?? "Recipes",
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= searchController.recipes.length) {
                  return searchController.isLoadingMoreRecipes
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : null;
                }
                return _buildRecipeCard(searchController.recipes[index]);
              },
              childCount: searchController.recipes.length +
                  (searchController.isLoadingMoreRecipes ? 1 : 0),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildSectionHeader(String title,
      {bool showAction = false, Widget? actionWidget}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (showAction && actionWidget != null) actionWidget,
        ],
      ),
    );
  }

  Widget _buildFiltersButton() {
    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.tune),
          if (searchController.recipeFilters.hasActiveFilters)
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
    );
  }

  Widget _buildUserCard(UserSearchResult user) {
    final isCurrentUser = user.viewerIsMe;

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Save search to history when user taps a result
            searchController.commitCurrentQueryToHistory();
            if (isCurrentUser) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    auth: widget.auth!,
                    apiClient: widget.apiClient,
                    shoppingListController: widget.shoppingListController,
                  ),
                ),
              );
            } else if (widget.auth?.isLoggedIn == true) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    auth: widget.auth!,
                    apiClient: widget.apiClient,
                    shoppingListController: widget.shoppingListController,
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
                buildUserAvatar(context, user.avatarUrl, user.username,
                    radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? user.username,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "@${user.username}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
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
  }

  Widget _buildRecipeCard(SearchResult recipe) {
    final date = formatDate(context, recipe.createdAt);

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Save search to history when user taps a result
            searchController.commitCurrentQueryToHistory();
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          buildUserAvatar(context, recipe.authorAvatarUrl,
                              recipe.authorUsername),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${recipe.authorDisplayName ?? recipe.authorUsername} • @${recipe.authorUsername} • $date",
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
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
        filters: searchController.recipeFilters,
        onApply: (filters) {
          searchController.updateFilters(filters);

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
          searchController.updateFilters(RecipeSearchFilters());
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
    _cookingTimeMinController.text =
        widget.filters.cookingTimeMin?.toString() ?? "";
    _cookingTimeMaxController.text =
        widget.filters.cookingTimeMax?.toString() ?? "";
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
    final cookingTimeMin = _cookingTimeMinController.text.trim().isEmpty
        ? null
        : int.tryParse(_cookingTimeMinController.text.trim());
    final cookingTimeMax = _cookingTimeMaxController.text.trim().isEmpty
        ? null
        : int.tryParse(_cookingTimeMaxController.text.trim());

    if (cookingTimeMin != null &&
        cookingTimeMax != null &&
        cookingTimeMin > cookingTimeMax) {
      final localizations = AppLocalizations.of(context);
      setState(() {
        _cookingTimeError = localizations?.minTimeCannotBeGreater ??
            "Minimum time cannot be greater than maximum time";
      });
      ErrorUtils.showError(
          context,
          localizations?.minCookingTimeCannotBeGreater ??
              "Minimum cooking time cannot be greater than maximum time");
      return;
    }

    setState(() {
      _cookingTimeError = null;
    });

    final filters = RecipeSearchFilters(
      cuisine: _cuisineController.text.trim().isEmpty
          ? null
          : _cuisineController.text.trim(),
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
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      final theme = Theme.of(context);
                      return _FilterSection(
                        title: localizations?.cuisine ?? "Cuisine",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _cuisineController,
                              decoration: InputDecoration(
                                hintText: localizations?.cuisineExample ??
                                    "e.g., Italian, Mexican, Asian",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.restaurant),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: cuisineOptions.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final option = cuisineOptions[index];
                                  final label = option.getLabel(localizations);
                                  final isSelected = _cuisineController.text == label;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _cuisineController.text =
                                            isSelected ? "" : label;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                                .withValues(alpha: 0.15)
                                            : theme.colorScheme.surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: isSelected
                                            ? Border.all(
                                                color: theme.colorScheme.primary,
                                                width: 1)
                                            : null,
                                      ),
                                      child: Text(
                                        option.getLabel(localizations),
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.tags ?? "Tags",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recipeCategories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final category = recipeCategories[index];
                                  final label = category.getLabel(localizations);
                                  final isSelected =
                                      _selectedTags.contains(label);
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(label),
                                    avatar: Icon(category.icon, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedTags.add(label);
                                        } else {
                                          _selectedTags.remove(label);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              localizations?.dietaryPreferences ?? "Dietary",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: dietaryPreferences.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final pref = dietaryPreferences[index];
                                  final label = pref.getLabel(localizations);
                                  final isSelected =
                                      _selectedTags.contains(label);
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(label),
                                    avatar: Icon(pref.icon, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedTags.add(label);
                                        } else {
                                          _selectedTags.remove(label);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tagController,
                                    decoration: InputDecoration(
                                      hintText:
                                          localizations?.addTag ?? "Add a tag",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon:
                                          const Icon(Icons.label_outline),
                                    ),
                                    onSubmitted: (_) => _addTag(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _addTag,
                                  icon: const Icon(Icons.add_circle),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            // Only show custom (non-predefined) tags below
                            if (_selectedTags.any((t) =>
                                !recipeCategories.any((c) => c.getLabel(localizations) == t) &&
                                !dietaryPreferences.any((d) => d.getLabel(localizations) == t))) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedTags
                                    .where((t) =>
                                        !recipeCategories
                                            .any((c) => c.getLabel(localizations) == t) &&
                                        !dietaryPreferences
                                            .any((d) => d.getLabel(localizations) == t))
                                    .map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    onDeleted: () => _removeTag(tag),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 18),
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
                                      hintText: localizations?.addTag
                                              .replaceAll("tag", "ingredient") ??
                                          "Add ingredient",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(
                                          Icons.shopping_cart_outlined),
                                    ),
                                    onSubmitted: (_) => _addIngredient(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _addIngredient,
                                  icon: const Icon(Icons.add_circle),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
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
                                    onDeleted: () =>
                                        _removeIngredient(ingredient),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 18),
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
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.cookingTimeMinutes ??
                            "Cooking Time (minutes)",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _cookingTimeMinController,
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
                                      prefixIcon:
                                          const Icon(Icons.timer_outlined),
                                    ),
                                    onChanged: (value) {
                                      if (_cookingTimeError != null) {
                                        setState(() {
                                          _cookingTimeError = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _cookingTimeMaxController,
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
                                      if (_cookingTimeError != null) {
                                        setState(() {
                                          _cookingTimeError = null;
                                        });
                                      }
                                    },
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
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _FilterSection(
                        title: localizations?.difficulty ?? "Difficulty",
                        child: SegmentedButton<String?>(
                          segments: [
                            ButtonSegment(
                                value: "easy",
                                label: Text(localizations?.easy ?? "Easy")),
                            ButtonSegment(
                                value: "medium",
                                label: Text(localizations?.medium ?? "Medium")),
                            ButtonSegment(
                                value: "hard",
                                label: Text(localizations?.hard ?? "Hard")),
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _applyFilters,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                      AppLocalizations.of(context)?.applyFilters ?? "Apply Filters"),
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

class _CookWithIngredientsCard extends StatelessWidget {
  const _CookWithIngredientsCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.kitchen_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.cookWithWhatIHave ?? "Cook with What I Have",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations?.findRecipesWithIngredients ??
                          "Find recipes based on ingredients you have",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
