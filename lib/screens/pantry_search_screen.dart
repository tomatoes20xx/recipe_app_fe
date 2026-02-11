import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../search/search_api.dart";
import "../search/search_models.dart";
import "../utils/error_utils.dart";
import "../widgets/empty_state_widget.dart";

class PantrySearchScreen extends StatefulWidget {
  const PantrySearchScreen({
    super.key,
    required this.apiClient,
    this.auth,
  });

  final ApiClient apiClient;
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
  String? _error;
  int _matchThreshold = 70;

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
        !_isLoadingMore &&
        _nextCursor != null) {
      _loadMore();
    }
  }

  void _addIngredient(String ingredient) {
    final trimmed = ingredient.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    if (_selectedIngredients.contains(trimmed)) return;

    setState(() {
      _selectedIngredients.add(trimmed);
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
      ErrorUtils.showError(context, "Please add at least one ingredient");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
      _nextCursor = null;
      _hasSearched = true;
    });

    try {
      final response = await searchApi.searchByIngredients(
        haveIngredients: _selectedIngredients,
        matchThreshold: _matchThreshold,
      );

      if (!mounted) return;

      setState(() {
        _results = response.items;
        _nextCursor = response.nextCursor;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextCursor == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await searchApi.searchByIngredients(
        haveIngredients: _selectedIngredients,
        matchThreshold: _matchThreshold,
        cursor: _nextCursor,
      );

      if (!mounted) return;

      setState(() {
        _results.addAll(response.items);
        _nextCursor = response.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _openRecipeDetail(SearchResult recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipe.id,
          apiClient: widget.apiClient,
          auth: widget.auth,
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(localizations?.somethingWentWrong ?? "Something went wrong"),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _search,
              child: Text(localizations?.retry ?? "Retry"),
            ),
          ],
        ),
      );
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
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
                  decoration: InputDecoration(
                    hintText: localizations?.enterIngredient ?? "Enter an ingredient...",
                    prefixIcon: const Icon(Icons.add),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedIngredients.map((ingredient) {
                return InputChip(
                  label: Text(ingredient),
                  onDeleted: () => onRemoveIngredient(ingredient),
                  deleteIcon: const Icon(Icons.close, size: 18),
                );
              }).toList(),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and match percentage
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (match != null) ...[
                    const SizedBox(width: 12),
                    _MatchBadge(percentage: match.percentage),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Author
              Text(
                "${recipe.authorDisplayName ?? recipe.authorUsername} • @${recipe.authorUsername}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
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
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        _formatCookingTime(recipe),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                    if ((recipe.cookingTimeMin != null || recipe.cookingTimeMax != null) && recipe.difficulty != null)
                      const SizedBox(width: 16),
                    if (recipe.difficulty != null)
                      Text(
                        recipe.difficulty!,
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
    );
  }

  String _formatCookingTime(SearchResult recipe) {
    if (recipe.cookingTimeMin != null && recipe.cookingTimeMax != null) {
      return "${recipe.cookingTimeMin}-${recipe.cookingTimeMax} min";
    } else if (recipe.cookingTimeMin != null) {
      return "${recipe.cookingTimeMin}+ min";
    } else {
      return "Up to ${recipe.cookingTimeMax} min";
    }
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 100
        ? Colors.green
        : percentage >= 80
            ? Theme.of(context).colorScheme.primary
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        "$percentage%",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
