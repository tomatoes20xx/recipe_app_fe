import "package:flutter/material.dart";

import "../analytics/analytics_api.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../theme/app_tokens.dart";
import "../theme/token_input.dart";
import "../utils/ui_utils.dart";
import "../widgets/common/recipe_grid_tile.dart";
import "../widgets/common/skeletons.dart";
import "../widgets/common/token_widgets.dart";
import "../recipes/recipe_detail_screen.dart";
import "../search/search_api.dart";
import "../search/search_models.dart";
import "../shopping/shopping_list_controller.dart";
import "../utils/error_utils.dart";
import "../widgets/empty_state_widget.dart";
import "../widgets/search/search_notice.dart";

class PantrySearchScreen extends StatefulWidget {
  const PantrySearchScreen({
    super.key,
    required this.apiClient,
    required this.shoppingListController,
    this.auth,
  });

  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final AuthController? auth;

  @override
  State<PantrySearchScreen> createState() => _PantrySearchScreenState();
}

class _PantrySearchScreenState extends State<PantrySearchScreen> {
  late final SearchApi searchApi;
  final TextEditingController _ingredientController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<String> _selectedIngredients = [];
  List<SearchResult> _results = [];
  String? _nextCursor;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  bool _chipsExpanded = false;
  String? _error;
  int _matchThreshold = 70;

  // What the current results were searched with. Chips and the slider stay
  // editable, so paging must reuse these, not the live values.
  List<String> _searchedIngredients = const [];
  int _searchedThreshold = 70;

  // Bumped on every new search; responses for an older one are dropped.
  int _gen = 0;

  /// Nothing reached the threshold; showing the closest recipes below it.
  bool _relaxed = false;
  List<SearchCorrection> _corrections = const [];

  @override
  void initState() {
    super.initState();
    searchApi = SearchApi(widget.apiClient);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        !_isLoadingMore &&
        _nextCursor != null) {
      _loadMore();
    }
  }

  /// Adds one chip per comma-separated entry ("ქათამი, ხახვი" → 2 chips).
  void _addIngredient(String input) {
    final entries = input
        .split(",")
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    setState(() {
      for (final entry in entries) {
        if (!_selectedIngredients.contains(entry)) _selectedIngredients.add(entry);
      }
      _ingredientController.clear();
    });
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _selectedIngredients.remove(ingredient);
    });
  }

  Future<void> _search() async {
    if (_selectedIngredients.isEmpty) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.addAtLeastOneIngredient ?? "Please add at least one ingredient");
      return;
    }

    _focusNode.unfocus(); // let the results show instead of the keyboard
    final gen = ++_gen;
    final ingredients = List<String>.unmodifiable(_selectedIngredients);
    final threshold = _matchThreshold;

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
      _results = [];
      _nextCursor = null;
      _relaxed = false;
      _corrections = const [];
      _hasSearched = true;
      _chipsExpanded = false;
      _searchedIngredients = ingredients;
      _searchedThreshold = threshold;
    });

    try {
      final response = await searchApi.searchByIngredients(
        haveIngredients: ingredients,
        matchThreshold: threshold,
        relaxed: true,
      );

      if (!mounted || gen != _gen) return;

      setState(() {
        _results = response.items;
        _nextCursor = response.nextCursor;
        _relaxed = response.relaxed;
        _corrections = response.corrections;
        _isLoading = false;
      });

      // Pantry searches weren't tracked before; this is the data for tuning.
      AnalyticsApi(widget.apiClient).trackSearch(
        query: ingredients.join(", "),
        filters: {
          "mode": "pantry",
          "threshold": threshold,
          "relaxed": response.relaxed,
          "results": response.items.length,
        },
      );
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = ErrorUtils.getUserFriendlyMessage(e, context);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _nextCursor == null) return;
    final gen = _gen;

    setState(() => _isLoadingMore = true);

    try {
      final response = await searchApi.searchByIngredients(
        haveIngredients: _searchedIngredients,
        matchThreshold: _searchedThreshold,
        relaxed: true,
        cursor: _nextCursor,
      );

      if (!mounted || gen != _gen) return;

      setState(() {
        _results.addAll(response.items);
        _nextCursor = response.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _openRecipeDetail(SearchResult recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipe.id,
          seed: RecipeSeed.fromSearchResult(recipe),
          apiClient: widget.apiClient,
          auth: widget.auth,
          shoppingListController: widget.shoppingListController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.cookWithWhatIHave ?? "Cook with What I Have"),
      ),
      body: Column(
        children: [
          // Ingredient input section
          _IngredientInputSection(
            controller: _ingredientController,
            focusNode: _focusNode,
            selectedIngredients: _selectedIngredients,
            onAddIngredient: _addIngredient,
            onRemoveIngredient: _removeIngredient,
            onSearch: _search,
            isLoading: _isLoading,
            matchThreshold: _matchThreshold,
            onThresholdChanged: (value) => setState(() => _matchThreshold = value),
            chipsExpanded: _chipsExpanded,
            onToggleChips: () => setState(() => _chipsExpanded = !_chipsExpanded),
          ),
          const Divider(height: 1),
          // Results section
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return const SingleChildScrollView(child: ListRowSkeleton(leadingSize: 64));
    }

    if (_error != null) {
      return ErrorStateWidget(message: _error!, onRetry: _search);
    }

    if (!_hasSearched) {
      return EmptyStateWidget(
        icon: Icons.kitchen_outlined,
        title: localizations?.addIngredientsToStart ?? "Add ingredients to start",
        description: localizations?.addIngredientsDescription ?? "Add the ingredients you have and we'll find recipes you can make",
      );
    }

    if (_results.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off_outlined,
        title: localizations?.noRecipesFound ?? "No recipes found",
        description: localizations?.tryDifferentIngredients ?? "Try adding different ingredients or lowering the match threshold",
      );
    }

    final notices = <String>[
      for (final c in _corrections)
        localizations?.pantryCorrection(c.from, c.to) ?? "Searched for “${c.to}” instead of “${c.from}”",
      if (_relaxed)
        localizations?.pantryRelaxedNotice(_searchedThreshold) ??
            "No recipe reaches $_searchedThreshold% — showing the closest matches",
    ];
    final headerCount = notices.isEmpty ? 0 : 1;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: headerCount + _results.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < headerCount) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                for (final text in notices)
                  SearchNotice(text, padding: const EdgeInsets.only(bottom: 4)),
              ],
            ),
          );
        }
        final index = i - headerCount;
        if (index == _results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final recipe = _results[index];
        return _RecipeMatchCard(
          recipe: recipe,
          onTap: () => _openRecipeDetail(recipe),
        );
      },
    );
  }
}

class _IngredientInputSection extends StatelessWidget {
  const _IngredientInputSection({
    required this.controller,
    required this.focusNode,
    required this.selectedIngredients,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
    required this.onSearch,
    required this.isLoading,
    required this.matchThreshold,
    required this.onThresholdChanged,
    required this.chipsExpanded,
    required this.onToggleChips,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selectedIngredients;
  final Function(String) onAddIngredient;
  final Function(String) onRemoveIngredient;
  final VoidCallback onSearch;
  final bool isLoading;
  final int matchThreshold;
  final Function(int) onThresholdChanged;
  final bool chipsExpanded;
  final VoidCallback onToggleChips;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: tokenInputDecoration(AppTokens.of(context), onPage: true).copyWith(
                    hintText: localizations?.enterIngredient ?? "Enter an ingredient...",
                    prefixIcon: const Icon(Icons.add),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    onAddIngredient(value);
                    focusNode.requestFocus();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () {
                  onAddIngredient(controller.text);
                  focusNode.requestFocus();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected ingredients chips
          if (selectedIngredients.isNotEmpty) ...[
            _IngredientsChipRow(
              ingredients: selectedIngredients,
              onRemove: onRemoveIngredient,
              expanded: chipsExpanded,
              onToggle: onToggleChips,
            ),
            const SizedBox(height: 16),
          ],

          // Match threshold slider
          Row(
            children: [
              Text(
                localizations?.matchThreshold ?? "Match threshold:",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              Text(
                "$matchThreshold%",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          Slider(
            value: matchThreshold.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            label: "$matchThreshold%",
            onChanged: (value) => onThresholdChanged(value.toInt()),
          ),
          const SizedBox(height: 8),

          // Search button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading || selectedIngredients.isEmpty ? null : onSearch,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(localizations?.findRecipes ?? "Find Recipes"),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeMatchCard extends StatelessWidget {
  const _RecipeMatchCard({
    required this.recipe,
    required this.onTap,
  });

  final SearchResult recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final match = recipe.ingredientMatch;
    final localizations = AppLocalizations.of(context);

    final t = AppTokens.of(context);
    final author = recipe.authorDisplayName?.trim().isNotEmpty == true
        ? recipe.authorDisplayName!.trim()
        : recipe.authorUsername;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
      color: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo, title and author, match percentage
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(author, style: TextStyle(fontSize: 13, color: t.ink2)),
                      ],
                    ),
                  ),
                  if (match != null) ...[
                    const SizedBox(width: 8),
                    _MatchBadge(percentage: match.percentage),
                  ],
                ],
              ),

              // Ingredient match info
              if (match != null) ...[
                const SizedBox(height: 12),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: match.percentage / 100,
                    minHeight: 6,
                    color: t.brand,
                    backgroundColor: t.field,
                  ),
                ),
                const SizedBox(height: 8),

                // Match count
                Text(
                  "${match.matchedCount}/${match.totalCount} ${localizations?.ingredients ?? "ingredients"}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                // Missing ingredients
                if (match.missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${localizations?.missing ?? "Missing"}: ${match.missing.join(", ")}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Staples the percentage assumes you have (salt, water, oil…)
                if (match.staples.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.kitchen_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          localizations?.pantryStaples(match.staples.join(", ")) ??
                              "You probably have: ${match.staples.join(", ")}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              // Cooking time and difficulty
              if (recipe.cookingTimeMin != null || recipe.difficulty != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (recipe.cookingTimeMin != null || recipe.cookingTimeMax != null) ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatCookingTime(localizations, recipe.cookingTimeMin, recipe.cookingTimeMax)!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                    if ((recipe.cookingTimeMin != null || recipe.cookingTimeMax != null) && recipe.difficulty != null)
                      const SizedBox(width: 16),
                    if (recipe.difficulty != null)
                      Text(
                        _localizedDifficulty(recipe.difficulty!, localizations),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _localizedDifficulty(String difficulty, AppLocalizations? l10n) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return l10n?.easy ?? difficulty;
      case 'medium':
        return l10n?.medium ?? difficulty;
      case 'hard':
        return l10n?.hard ?? difficulty;
      default:
        return difficulty;
    }
  }
}

class _IngredientsChipRow extends StatelessWidget {
  const _IngredientsChipRow({
    required this.ingredients,
    required this.onRemove,
    required this.expanded,
    required this.onToggle,
  });

  final List<String> ingredients;
  final Function(String) onRemove;
  final bool expanded;
  final VoidCallback onToggle;

  static const int _collapsedMax = 4;

  Widget _chip(String ingredient) => TokenChip(
        label: ingredient,
        selected: true,
        onDeleted: () => onRemove(ingredient),
      );

  Widget _toggleChip(BuildContext context, String label) => TokenChip(label: label, onTap: onToggle);

  @override
  Widget build(BuildContext context) {
    final hasOverflow = ingredients.length > _collapsedMax;

    final localizations = AppLocalizations.of(context);

    if (expanded && hasOverflow) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            children: [
              ...ingredients.map(_chip),
              _toggleChip(context, localizations?.showLess ?? 'show less'),
            ],
          ),
        ),
      );
    }

    final visible = hasOverflow ? ingredients.take(_collapsedMax).toList() : ingredients;
    final hiddenCount = ingredients.length - visible.length;

    return Wrap(
      spacing: 8,
      children: [
        ...visible.map(_chip),
        if (hasOverflow) _toggleChip(context, localizations?.nMore(hiddenCount) ?? '+$hiddenCount more'),
      ],
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percentage});

  final int percentage;

  /// 80%+ in the brand greens, lower in neutral `field`/`ink2`.
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final good = percentage >= 80;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: good ? t.soft : t.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$percentage%",
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: good ? t.brandInk : t.ink2),
      ),
    );
  }
}
