import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../api/api_client.dart";
import "../analytics/analytics_api.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../constants/cuisines.dart";
import "../constants/dietary_preferences.dart";
import "../constants/enums.dart";
import "../constants/recipe_categories.dart";
import "../localization/app_localizations.dart";
import "../theme/app_tokens.dart";
import "../theme/token_input.dart";
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
import "../widgets/common/recipe_grid_tile.dart";
import "../widgets/common/skeletons.dart";
import "../widgets/common/user_list_tile.dart";
import "../widgets/common/common_widgets.dart";
import "../widgets/empty_state_widget.dart";
import "../widgets/search/search_notice.dart";
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
    final auth = widget.auth;
    if (auth == null) return;
    final newFollowing = !user.viewerIsFollowing;
    if (!await requireVerifiedAccount(context, auth, AccountReason.follow)) return;
    if (!mounted) return;

    try {
      await searchController.toggleFollow(user.username);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          newFollowing
              ? (localizations?.nowFollowingUser(user.username) ?? "Now following ${user.username}")
              : (localizations?.unfollowedUser(user.username) ?? "Unfollowed ${user.username}"),
        );
      }
    } catch (e) {
      if (mounted && !await handleAuthError(context, auth, e, AccountReason.follow) && mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchTextController.dispose();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query, {bool saveToHistory = false}) async {
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
    if (filters.difficulty != null) {
      filterData["difficulty"] = filters.difficulty!.apiValue;
    }

    analyticsApi.trackSearch(
      query: trimmedQuery,
      filters: filterData.isEmpty ? null : filterData,
    );

    // Search runs on submit, so there is nothing to debounce.
    _lastSearchedQuery = trimmedQuery;
    await searchController.search(trimmedQuery, saveToHistory: saveToHistory);
    // A failed search must not block submitting the same text again.
    if (searchController.error != null &&
        searchController.currentQuery == trimmedQuery &&
        _lastSearchedQuery == trimmedQuery) {
      _lastSearchedQuery = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        // Bottom-nav tab root: 20px title, like the Profile tab.
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 20),
        title: Row(
          children: [
            Text(localizations?.search ?? "Search"),
            const SizedBox(width: 16),
            Expanded(
              child: TokenSearchField(
                controller: _searchTextController,
                hintText: localizations?.searchRecipes ?? "Search recipes, users...",
                textInputAction: TextInputAction.search,
                onSubmitted: (query) {
                  if (query.trim().isNotEmpty) {
                    _performSearch(query.trim());
                  }
                },
                onCleared: () {
                  // So submitting the same query again searches again.
                  _lastSearchedQuery = null;
                  searchController.clear();
                },
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
      return const SingleChildScrollView(child: ListRowSkeleton(leadingSize: 64));
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTokens.of(context).ink2),
                ),
                TextButton(
                  onPressed: () => searchController.clearHistory(),
                  child: Text(localizations?.clearAll ?? "Clear All"),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: searchController.recentSearches.map((query) {
                return TokenChip(
                  label: query,
                  icon: Icons.history_rounded,
                  onDeleted: () => searchController.removeFromHistory(query),
                  onTap: () {
                    // Show the query in the box (with its clear button), then search it.
                    _searchTextController.text = query;
                    _performSearch(query, saveToHistory: true);
                  },
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
    // With users on screen, a recipe reload (filter change) or a recipe error
    // still needs its own section; otherwise recipes would just vanish.
    final recipesLoading = searchController.isLoading && !hasRecipes;
    final recipesError = searchController.error != null && !hasRecipes;

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
        if (hasRecipes || recipesLoading || recipesError) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              localizations?.recipes ?? "Recipes",
            ),
          ),
          if (searchController.correctedQuery != null)
            SliverToBoxAdapter(
              child: SearchNotice(
                localizations?.searchShowingResultsFor(searchController.correctedQuery!) ??
                    "Showing results for “${searchController.correctedQuery}”",
              ),
            ),
          if (searchController.relaxedResults)
            SliverToBoxAdapter(
              child: SearchNotice(
                localizations?.searchNoExactMatches ??
                    "No exact matches — showing similar recipes",
              ),
            ),
          if (recipesLoading)
            const SliverToBoxAdapter(child: ListRowSkeleton(count: 3, leadingSize: 64))
          else if (recipesError)
            SliverToBoxAdapter(
              child: ErrorStateWidget(
                message: ErrorUtils.getUserFriendlyMessage(searchController.error!, context),
                onRetry: () => searchController.updateFilters(searchController.recipeFilters),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTokens.of(context).ink),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: UserListTile(
        username: user.username,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        trailing: widget.auth != null && !user.viewerIsMe
            ? FollowButton(isFollowing: user.viewerIsFollowing, onTap: () => _handleFollowToggle(user))
            : null,
        onTap: () {
          // Save search to history when user taps a result
          searchController.commitCurrentQueryToHistory();
          if (widget.auth != null) {
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
      ),
    );
  }

  /// Photo, title, then author and time, on a `card` row like the user rows.
  Widget _buildRecipeCard(SearchResult recipe) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final author = recipe.authorDisplayName?.trim().isNotEmpty == true
        ? recipe.authorDisplayName!.trim()
        : recipe.authorUsername;
    final time = formatCookingTime(l, recipe.cookingTimeMin, recipe.cookingTimeMax);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                RecipeThumb(imageUrl: recipe.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [author, ?time].join(" · "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.ink2),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: t.ink2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showAppBottomSheet(
      context: context,
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
          if (filters.difficulty != null) {
            filterData["difficulty"] = filters.difficulty!.apiValue;
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
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: sheetTopRadius,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SheetHandle(),
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTokens.of(context).ink),
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
                      return _FilterSection(
                        title: localizations?.cuisine ?? "Cuisine",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _cuisineController,
                              decoration: tokenInputDecoration(AppTokens.of(context)).copyWith(
                                hintText: localizations?.cuisineExample ??
                                    "e.g., Italian, Mexican, Asian",
                                prefixIcon: const Icon(Icons.restaurant),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: cuisineOptions.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final label = cuisineOptions[index].getLabel(localizations);
                                  final isSelected = _cuisineController.text == label;
                                  return TokenChip(
                                    label: label,
                                    selected: isSelected,
                                    onTap: () => setState(() {
                                      _cuisineController.text = isSelected ? "" : label;
                                    }),
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
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recipeCategories.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final category = recipeCategories[index];
                                  final label = category.getLabel(localizations);
                                  final isSelected = _selectedTags.contains(label);
                                  return TokenChip(
                                    label: label,
                                    icon: category.icon,
                                    selected: isSelected,
                                    onTap: () => setState(() {
                                      if (isSelected) {
                                        _selectedTags.remove(label);
                                      } else {
                                        _selectedTags.add(label);
                                      }
                                    }),
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
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: dietaryPreferences.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final pref = dietaryPreferences[index];
                                  final label = pref.getLabel(localizations);
                                  final isSelected = _selectedTags.contains(label);
                                  return TokenChip(
                                    label: label,
                                    icon: pref.icon,
                                    selected: isSelected,
                                    onTap: () => setState(() {
                                      if (isSelected) {
                                        _selectedTags.remove(label);
                                      } else {
                                        _selectedTags.add(label);
                                      }
                                    }),
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
                                    decoration: tokenInputDecoration(AppTokens.of(context)).copyWith(
                                      hintText:
                                          localizations?.addTag ?? "Add a tag",
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
                                  return TokenChip(
                                    label: tag,
                                    selected: true,
                                    onDeleted: () => _removeTag(tag),
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
                                    decoration: tokenInputDecoration(AppTokens.of(context)).copyWith(
                                      hintText: localizations?.addTag
                                              .replaceAll("tag", "ingredient") ??
                                          "Add ingredient",
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
                                  return TokenChip(
                                    label: ingredient,
                                    selected: true,
                                    onDeleted: () => _removeIngredient(ingredient),
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
                                    decoration: tokenInputDecoration(AppTokens.of(context)).copyWith(
                                      labelText: localizations?.min ?? "Min",
                                      hintText: "0",
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
                                    decoration: tokenInputDecoration(AppTokens.of(context)).copyWith(
                                      labelText: localizations?.max ?? "Max",
                                      hintText: "120",
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
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final (value, label) in [
                              (Difficulty.easy, localizations?.easy ?? "Easy"),
                              (Difficulty.medium, localizations?.medium ?? "Medium"),
                              (Difficulty.hard, localizations?.hard ?? "Hard"),
                            ])
                              TokenChip(
                                label: label,
                                selected: _currentFilters.difficulty == value,
                                onTap: () => setState(() {
                                  _currentFilters = _currentFilters.copyWith(
                                    difficulty: _currentFilters.difficulty == value ? null : value,
                                  );
                                }),
                              ),
                          ],
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
        ),
        ),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTokens.of(context).ink),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _CookWithIngredientsCard extends StatelessWidget {
  const _CookWithIngredientsCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  /// Styled like the Profile tab's library tiles: `card`, 1px `line`,
  /// radius 18, a `soft` icon tile.
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final localizations = AppLocalizations.of(context);

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.kitchen_outlined, color: t.brandInk, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.cookWithWhatIHave ?? "Cook with What I Have",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizations?.findRecipesWithIngredients ??
                          "Find recipes based on ingredients you have",
                      style: TextStyle(fontSize: 13, color: t.ink2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
