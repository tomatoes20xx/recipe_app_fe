import "dart:ui";

import "package:facebook_app_events/facebook_app_events.dart";
import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../collections/add_to_collection_bottom_sheet.dart";
import "../constants/cuisines.dart";
import "../constants/dietary_preferences.dart";
import "../constants/recipe_categories.dart";
import "../localization/app_localizations.dart";
import "../screens/create_recipe_screen.dart";
import "../screens/profile_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/ingredient_action_bar.dart";
import "../widgets/section_title_widget.dart";
import "../widgets/sharing/follower_selection_bottom_sheet.dart";
import "../reports/report_bottom_sheet.dart";
import "../reports/report_models.dart";
import "comments_bottom_sheet.dart";
import "liked_by_bottom_sheet.dart";
import "recipe_api.dart";
import "recipe_detail_controller.dart";
import "recipe_detail_models.dart";
import "recipe_sharing_controller.dart";

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.apiClient,
    this.auth,
    required this.shoppingListController,
  });

  final String recipeId;
  final ApiClient apiClient;
  final AuthController? auth;
  final ShoppingListController shoppingListController;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeDetailController c;
  late final RecipeApi recipeApi;
  late final RecipeSharingController _sharingController;
  bool _isLiking = false;
  bool _isBookmarking = false;
  bool? _viewerHasLiked;
  bool? _viewerHasBookmarked;
  int? _localLikes;
  int? _localBookmarks;
  int? _localComments;
  final Set<String> _checkedIngredients = {};
  final Set<String> _selectedForShopping = {};
  bool _isSelectionMode = false;
  bool _viewContentLogged = false;

  @override
  void initState() {
    super.initState();
    recipeApi = RecipeApi(widget.apiClient);
    c = RecipeDetailController(api: recipeApi, recipeId: widget.recipeId);
    c.addListener(_onChanged);
    c.load();

    // Initialize sharing controller
    _sharingController = RecipeSharingController(
      recipeApi: recipeApi,
      recipeId: widget.recipeId,
    );
  }

  void _onChanged() {
    if (!_viewContentLogged && c.recipe != null) {
      _viewContentLogged = true;
      final recipe = c.recipe!;
      FacebookAppEvents().logViewContent(
        id: recipe.id,
        type: recipe.cuisine ?? 'recipe',
      );
    }
    if (mounted) {
      setState(() {
        _localLikes = null;
        _localBookmarks = null;
        _localComments = null;
        _viewerHasLiked = c.recipe?.viewerHasLiked;
        _viewerHasBookmarked = c.recipe?.viewerHasBookmarked;
      });
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    c.dispose();
    _sharingController.dispose();
    super.dispose();
  }

  void _toggleIngredient(String id) {
    setState(() {
      if (_isSelectionMode) {
        // In selection mode, toggle for shopping list
        if (_selectedForShopping.contains(id)) {
          _selectedForShopping.remove(id);
          // Exit selection mode if no ingredients are selected
          if (_selectedForShopping.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedForShopping.add(id);
        }
      } else {
        // Normal mode - enter selection mode and select the ingredient
        _isSelectionMode = true;
        _selectedForShopping.clear();
        _selectedForShopping.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedForShopping.clear();
    });
  }

  void _markSelectedAsHave() {
    setState(() {
      // Add to checked ingredients (strikethrough)
      _checkedIngredients.addAll(_selectedForShopping);
      _exitSelectionMode();
    });
  }

  Future<void> _toggleLike() async {
    final r = c.recipe;
    if (r == null || _isLiking) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.pleaseLogInToLike ?? "Please log in to like recipes");
      return;
    }

    setState(() => _isLiking = true);

    try {
      final wasLiked = _viewerHasLiked ?? false;
      if (wasLiked) {
        await recipeApi.unlike(r.id);
      } else {
        await recipeApi.like(r.id);
      }
      if (!mounted) return;
      final base = _localLikes ?? r.counts.likes;
      setState(() {
        _viewerHasLiked = !wasLiked;
        _localLikes = base + (wasLiked ? -1 : 1);
      });
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final r = c.recipe;
    if (r == null || _isBookmarking) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.pleaseLogInToBookmark ?? "Please log in to bookmark recipes");
      return;
    }

    setState(() => _isBookmarking = true);

    try {
      final wasBookmarked = _viewerHasBookmarked ?? false;
      if (wasBookmarked) {
        await recipeApi.unbookmark(r.id);
      } else {
        await recipeApi.bookmark(r.id);
      }
      if (!mounted) return;
      final base = _localBookmarks ?? r.counts.bookmarks;
      setState(() {
        _viewerHasBookmarked = !wasBookmarked;
        _localBookmarks = base + (wasBookmarked ? -1 : 1);
      });
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isBookmarking = false);
      }
    }
  }

  Future<void> _onBookmarkLongPress() async {
    final r = c.recipe;
    if (r == null) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.pleaseLogInToUseCollections ?? "Please log in to use collections");
      return;
    }
    final result = await showAddToCollectionBottomSheet(
      context: context,
      apiClient: widget.apiClient,
      recipeId: r.id,
    );
    if (result.changed && mounted) {
      final wasBookmarked = _viewerHasBookmarked ?? r.viewerHasBookmarked;
      if (result.isBookmarked != wasBookmarked) {
        setState(() {
          _viewerHasBookmarked = result.isBookmarked;
          final base = _localBookmarks ?? r.counts.bookmarks;
          _localBookmarks = base + (result.isBookmarked ? 1 : -1);
        });
      }
    }
  }

  Future<void> _onShareTap() async {
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.pleaseLogInToShare ?? "Please log in to share recipes");
      return;
    }

    // Load shared-with list if not already loaded
    if (_sharingController.sharedWith.isEmpty && !_sharingController.isLoading) {
      await _sharingController.loadSharedWith();
    }

    if (!mounted) return;

    await showFollowerSelectionBottomSheet(
      context: context,
      apiClient: widget.apiClient,
      auth: widget.auth!,
      alreadySharedWith: _sharingController.sharedWith.map((u) => u.userId).toList(),
      showShareTypeSelector: false,
      onShare: (userIds, _) async {
        try {
          await _sharingController.shareWith(userIds);
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ErrorUtils.showSuccess(
              context,
              localizations?.recipeSharedSuccess ?? "Recipe shared successfully!",
            );
            // Refresh recipe to get updated share count
            c.refresh();
          }
        } catch (e) {
          if (mounted) {
            ErrorUtils.showError(context, e);
          }
        }
      },
    );
  }

  Future<void> _onLikeLongPress() async {
    final r = c.recipe;
    if (r == null || r.likedBy == null) return;

    await showLikedByBottomSheet(
      context: context,
      likedBy: r.likedBy!,
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, RecipeDetail recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations?.deleteRecipe ?? "Delete Recipe"),
          content: Text(
            "${localizations?.areYouSureDeleteRecipe ?? "Are you sure you want to delete"} \"${recipe.title}\"? ${localizations?.thisActionCannotBeUndone ?? "This action cannot be undone."}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations?.cancel ?? "Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(localizations?.delete ?? "Delete"),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final recipeApi = RecipeApi(widget.apiClient);
      await recipeApi.deleteRecipe(recipe.id);

      if (!mounted) return;
      final localizations = AppLocalizations.of(this.context);
      ErrorUtils.showSuccess(
        this.context,
        localizations?.recipeDeletedSuccessfully ?? "Recipe deleted successfully",
      );
      if (!mounted) return;
      Navigator.of(this.context).pop();
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showError(this.context, e);
    }
  }

  Future<void> _handleReportRecipe() async {
    final r = c.recipe;
    if (r == null) return;

    if (!(widget.auth?.isLoggedIn ?? false)) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.pleaseLogInToReport ?? "Please log in to report recipes");
      return;
    }

    await showReportBottomSheet(
      context: context,
      targetType: ReportTargetType.recipe,
      targetId: r.id,
      apiClient: widget.apiClient,
    );
    // Success feedback is already shown in the bottom sheet
    // No additional action needed since backend is idempotent
  }

  @override
  Widget build(BuildContext context) {
    final r = c.recipe;
    final isOwner = widget.auth != null &&
        widget.auth!.isLoggedIn &&
        r != null &&
        widget.auth!.me?["username"]?.toString() == r.authorUsername;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: Colors.white.withValues(alpha: 0.50),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    _AppBarIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (isOwner) ...[
                      _AppBarIconButton(
                        icon: Icons.edit,
                        tooltip: AppLocalizations.of(context)?.editRecipe ?? "Edit Recipe",
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreateRecipeScreen(
                                apiClient: widget.apiClient,
                                recipeId: r.id,
                                recipe: r,
                              ),
                            ),
                          );
                          if (result == true && mounted) {
                            c.refresh();
                          }
                        },
                      ),
                      _AppBarIconButton(
                        icon: Icons.delete_outline,
                        tooltip: AppLocalizations.of(context)?.deleteRecipe ?? "Delete Recipe",
                        onPressed: () => _showDeleteConfirmation(context, r),
                      ),
                    ],
                    if (!isOwner && widget.auth?.isLoggedIn == true && r != null)
                      _AppBarIconButton(
                        icon: Icons.flag_outlined,
                        tooltip: AppLocalizations.of(context)?.reportRecipe ?? "Report Recipe",
                        onPressed: _handleReportRecipe,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : c.error != null
              ? _ErrorView(
                  error: c.error!,
                  onRetry: () => c.load(),
                )
              : r == null
                  ? Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Center(child: Text(localizations?.notFound ?? "Not found"));
                      },
                    )
                  : Stack(
                      children: [
                        // Hero image section (top 60%)
                        _HeroImageSection(
                          images: r.images,
                          onImageTap: (index) => _openImageViewer(index, r.images),
                        ),
                        // Draggable content sheet
                        DraggableScrollableSheet(
                          initialChildSize: 0.55,
                          minChildSize: 0.55,
                          maxChildSize: 0.95,
                          snap: true,
                          snapSizes: const [0.55, 0.95],
                          builder: (context, scrollController) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: RefreshIndicator(
                                onRefresh: c.refresh,
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: _ContentBody(
                                    recipe: r,
                                    apiClient: widget.apiClient,
                                    auth: widget.auth,
                                    shoppingListController: widget.shoppingListController,
                                    counts: RecipeCounts(
                                      likes: _localLikes ?? r.counts.likes,
                                      comments: _localComments ?? r.counts.comments,
                                      bookmarks: _localBookmarks ?? r.counts.bookmarks,
                                      shares: r.counts.shares,
                                    ),
                                    viewerHasLiked: _viewerHasLiked ?? false,
                                    viewerHasBookmarked: _viewerHasBookmarked ?? false,
                                    isLiking: _isLiking,
                                    isBookmarking: _isBookmarking,
                                    onLikeTap: _toggleLike,
                                    onLikeLongPress: r.likedBy != null ? _onLikeLongPress : null,
                                    onBookmarkTap: _toggleBookmark,
                                    onBookmarkLongPress: _onBookmarkLongPress,
                                    onCommentTap: () {
                                      showCommentsBottomSheet(
                                        context: context,
                                        recipeId: r.id,
                                        apiClient: widget.apiClient,
                                        auth: widget.auth,
                                        onCommentPosted: () {
                                          if (mounted) {
                                            setState(() {
                                              _localComments = (_localComments ?? c.recipe?.counts.comments ?? 0) + 1;
                                            });
                                          }
                                        },
                                      );
                                    },
                                    checkedIngredients: _checkedIngredients,
                                    selectedForShopping: _selectedForShopping,
                                    isSelectionMode: _isSelectionMode,
                                    onToggleIngredient: _toggleIngredient,
                                    isOwner: isOwner,
                                    shareCount: r.counts.shares,
                                    onShareTap: _onShareTap,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
      bottomNavigationBar: _isSelectionMode && _selectedForShopping.isNotEmpty && r != null
          ? IngredientActionBar(
              selectedIngredients: r.ingredients
                  .where((ing) => _selectedForShopping.contains(ing.id))
                  .toList(),
              recipeId: r.id,
              recipeName: r.title,
              recipeImage: r.images.isNotEmpty ? r.images.first.url : null,
              shoppingListController: widget.shoppingListController,
              apiClient: widget.apiClient,
              auth: widget.auth,
              onMarkAsHave: _markSelectedAsHave,
              onCancel: _exitSelectionMode,
            )
          : null,
    );
  }

  void _openImageViewer(int initialIndex, List<RecipeImage> images) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// Hero Image Section with gradient overlay
class _HeroImageSection extends StatefulWidget {
  const _HeroImageSection({
    required this.images,
    required this.onImageTap,
  });

  final List<RecipeImage> images;
  final Function(int) onImageTap;

  @override
  State<_HeroImageSection> createState() => _HeroImageSectionState();
}

class _HeroImageSectionState extends State<_HeroImageSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          // Image gallery
          if (widget.images.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return GestureDetector(
                  onTap: () => widget.onImageTap(index),
                  child: RecipeImageWidget(
                    imageUrl: image.url,
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.cover,
                  ),
                );
              },
            )
          else
            const RecipeFallbackImage(
              width: double.infinity,
              height: double.infinity,
              iconSize: 120,
            ),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Page indicators
          if (widget.images.length > 1)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Content Body widget
class _ContentBody extends StatelessWidget {
  const _ContentBody({
    required this.recipe,
    required this.apiClient,
    this.auth,
    required this.shoppingListController,
    required this.counts,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
    required this.isLiking,
    required this.isBookmarking,
    required this.onLikeTap,
    this.onLikeLongPress,
    required this.onBookmarkTap,
    this.onBookmarkLongPress,
    required this.onCommentTap,
    required this.checkedIngredients,
    required this.selectedForShopping,
    required this.isSelectionMode,
    required this.onToggleIngredient,
    required this.isOwner,
    required this.shareCount,
    required this.onShareTap,
  });

  final RecipeDetail recipe;
  final ApiClient apiClient;
  final AuthController? auth;
  final ShoppingListController shoppingListController;
  final RecipeCounts counts;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;
  final bool isLiking;
  final bool isBookmarking;
  final VoidCallback onLikeTap;
  final VoidCallback? onLikeLongPress;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback onCommentTap;
  final Set<String> checkedIngredients;
  final Set<String> selectedForShopping;
  final bool isSelectionMode;
  final Function(String) onToggleIngredient;
  final bool isOwner;
  final int shareCount;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            recipe.title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // User Info Row
          _UserInfoRow(r: recipe, apiClient: apiClient, auth: auth, shoppingListController: shoppingListController),
          const SizedBox(height: 16),

          // Description
          if (recipe.description != null && recipe.description!.trim().isNotEmpty) ...[
            Text(
              recipe.description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 16),
          ],

          // Engagement Bar
          _EngagementBar(
            counts: counts,
            viewerHasLiked: viewerHasLiked,
            viewerHasBookmarked: viewerHasBookmarked,
            isLiking: isLiking,
            isBookmarking: isBookmarking,
            onLikeTap: onLikeTap,
            onLikeLongPress: onLikeLongPress,
            onBookmarkTap: onBookmarkTap,
            onBookmarkLongPress: onBookmarkLongPress,
            onCommentTap: onCommentTap,
            isOwner: isOwner,
            shareCount: shareCount,
            onShareTap: onShareTap,
          ),
          const SizedBox(height: 16),

          // Quick Info Bar
          if (recipe.cookingTimeMin != null || recipe.cookingTimeMax != null || recipe.difficulty != null) ...[
            _QuickInfoBar(
              cookingTimeMin: recipe.cookingTimeMin,
              cookingTimeMax: recipe.cookingTimeMax,
              difficulty: recipe.difficulty,
            ),
            const SizedBox(height: 16),
          ],

          // Tags
          if (recipe.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipe.tags.map((tag) => _HashtagPill(tag: tag)).toList(),
            ),
            const SizedBox(height: 28),
          ],

          // Ingredients Section
          if (recipe.ingredients.isNotEmpty) ...[
            _IngredientsSection(
              ingredients: recipe.ingredients,
              checkedIds: checkedIngredients,
              selectedIds: selectedForShopping,
              isSelectionMode: isSelectionMode,
              onToggle: onToggleIngredient,
            ),
            const SizedBox(height: 16),
          ],

          // Nutrition Panel
          _NutritionPanel(recipeId: recipe.id, apiClient: apiClient),
          const SizedBox(height: 24),

          // Steps Section
          if (recipe.steps.isNotEmpty)
            _StepsSection(steps: recipe.steps),
        ],
      ),
    );
  }
}

// Quick Info Bar widget
class _QuickInfoBar extends StatelessWidget {
  const _QuickInfoBar({
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
  });

  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty;

  String _formatCookingTime(AppLocalizations? l) {
    final unit = l?.minuteAbbreviation ?? "min";
    if (cookingTimeMin != null && cookingTimeMax != null) {
      return "$cookingTimeMin $unit - $cookingTimeMax $unit";
    } else if (cookingTimeMin != null) {
      return "$cookingTimeMin+ $unit";
    } else {
      return "$cookingTimeMax $unit";
    }
  }

  String _getLocalizedDifficulty(AppLocalizations? l) {
    switch (difficulty?.toLowerCase()) {
      case "easy":
        return l?.easy ?? "Easy";
      case "medium":
        return l?.medium ?? "Medium";
      case "hard":
        return l?.hard ?? "Hard";
      default:
        return difficulty!;
    }
  }

  Color _getDifficultyColor(BuildContext context) {
    switch (difficulty?.toLowerCase()) {
      case "easy":
        return Colors.green;
      case "medium":
        return Colors.orange;
      case "hard":
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    final hasTime = cookingTimeMin != null || cookingTimeMax != null;
    final hasDifficulty = difficulty != null;
    if (!hasTime && !hasDifficulty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTime)
              Expanded(
                child: _QuickInfoItem(
                  icon: Icons.schedule,
                  iconColor: primary,
                  label: localizations?.prepTime ?? "PREP TIME",
                  value: _formatCookingTime(localizations),
                ),
              ),
            if (hasTime && hasDifficulty)
              Container(
                width: 1,
                height: 32,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            if (hasDifficulty)
              Expanded(
                child: _QuickInfoItem(
                  icon: Icons.bolt,
                  iconColor: primary,
                  label: localizations?.difficulty ?? "DIFFICULTY",
                  value: _getLocalizedDifficulty(localizations),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoItem extends StatelessWidget {
  const _QuickInfoItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Vertical Engagement sidebar widget
class _VerticalEngagementBar extends StatelessWidget {
  const _VerticalEngagementBar({
    required this.counts,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
    required this.isLiking,
    required this.isBookmarking,
    required this.onLikeTap,
    this.onLikeLongPress,
    required this.onBookmarkTap,
    this.onBookmarkLongPress,
    required this.onCommentTap,
    required this.isOwner,
    required this.shareCount,
    required this.onShareTap,
  });

  final RecipeCounts counts;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;
  final bool isLiking;
  final bool isBookmarking;
  final VoidCallback onLikeTap;
  final VoidCallback? onLikeLongPress;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback onCommentTap;
  final bool isOwner;
  final int shareCount;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EngagementButton(
            icon: viewerHasLiked ? Icons.favorite : Icons.favorite_border,
            count: counts.likes,
            isActive: viewerHasLiked,
            isLoading: isLiking,
            onTap: onLikeTap,
            onLongPress: onLikeLongPress,
            activeColor: const Color(0xFFE53935),
          ),
          _EngagementButton(
            icon: Icons.chat_bubble_outline,
            count: counts.comments,
            onTap: onCommentTap,
          ),
          _EngagementButton(
            icon: viewerHasBookmarked ? Icons.bookmark : Icons.bookmark_border,
            count: counts.bookmarks,
            isActive: viewerHasBookmarked,
            isLoading: isBookmarking,
            onTap: onBookmarkTap,
            onLongPress: onBookmarkLongPress,
            activeColor: const Color(0xFFE53935),
          ),
          _EngagementButton(
            icon: Icons.share,
            count: shareCount,
            onTap: onShareTap,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// Horizontal Engagement Bar widget
class _EngagementBar extends StatelessWidget {
  const _EngagementBar({
    required this.counts,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
    required this.isLiking,
    required this.isBookmarking,
    required this.onLikeTap,
    this.onLikeLongPress,
    required this.onBookmarkTap,
    this.onBookmarkLongPress,
    required this.onCommentTap,
    required this.isOwner,
    required this.shareCount,
    required this.onShareTap,
  });

  final RecipeCounts counts;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;
  final bool isLiking;
  final bool isBookmarking;
  final VoidCallback onLikeTap;
  final VoidCallback? onLikeLongPress;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback onCommentTap;
  final bool isOwner;
  final int shareCount;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EngagementButton(
            icon: viewerHasLiked ? Icons.favorite : Icons.favorite_border,
            count: counts.likes,
            isActive: viewerHasLiked,
            isLoading: isLiking,
            onTap: onLikeTap,
            onLongPress: onLikeLongPress,
            activeColor: const Color(0xFFE53935),
          ),
        ),
        Expanded(
          child: _EngagementButton(
            icon: Icons.chat_bubble_outline,
            count: counts.comments,
            onTap: onCommentTap,
          ),
        ),
        Expanded(
          child: _EngagementButton(
            icon: viewerHasBookmarked ? Icons.bookmark : Icons.bookmark_border,
            count: counts.bookmarks,
            isActive: viewerHasBookmarked,
            isLoading: isBookmarking,
            onTap: onBookmarkTap,
            onLongPress: onBookmarkLongPress,
            activeColor: const Color(0xFFE53935),
          ),
        ),
        Expanded(
          child: _EngagementButton(
            icon: Icons.share,
            count: shareCount,
            onTap: onShareTap,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _EngagementButton extends StatelessWidget {
  const _EngagementButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.isLoading = false,
    this.activeColor,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;
  final bool isLoading;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        onLongPress: isLoading ? null : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 22, color: color),
              const SizedBox(width: 6),
              Text(
                "$count",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}

// Ingredients Section widget
class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({
    required this.ingredients,
    required this.checkedIds,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onToggle,
  });

  final List<RecipeIngredient> ingredients;
  final Set<String> checkedIds;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations?.ingredients ?? "Ingredients",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              "${ingredients.length} ${localizations?.items ?? "items"}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...ingredients.map((ing) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _IngredientTile(
            ingredient: ing,
            isChecked: checkedIds.contains(ing.id),
            isSelected: selectedIds.contains(ing.id),
            isSelectionMode: isSelectionMode,
            onToggle: () => onToggle(ing.id),
          ),
        )),
      ],
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    required this.ingredient,
    required this.isChecked,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggle,
  });

  final RecipeIngredient ingredient;
  final bool isChecked;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggle;

  String _formatAmount() {
    final qty = ingredient.quantity == null ? "" : "${ingredient.quantity}";
    final unit = ingredient.unit == null ? "" : " ${ingredient.unit}";
    return "$qty$unit".trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCheckedOrSelected = isSelectionMode ? isSelected : isChecked;
    final amount = _formatAmount();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelectionMode && isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isCheckedOrSelected,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ingredient.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    decoration: !isSelectionMode && isChecked ? TextDecoration.lineThrough : null,
                    color: !isSelectionMode && isChecked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (amount.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Steps Section widget
class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitleWidget(
          text: "${localizations?.steps ?? "Steps"} (${steps.length})",
          variant: SectionTitleVariant.regular,
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) => _StepCard(
          stepNumber: entry.key + 1,
          step: entry.value,
          isLast: entry.key == steps.length - 1,
        )),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.step,
    required this.isLast,
  });

  final int stepNumber;
  final RecipeStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final lineColor = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number + vertical line
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      "$stepNumber",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Step text
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Text(
                  step.instruction,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// User Info Row widget
class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({required this.r, required this.apiClient, this.auth, required this.shoppingListController});
  final RecipeDetail r;
  final ApiClient apiClient;
  final AuthController? auth;
  final ShoppingListController shoppingListController;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(context, r.createdAt);
    final localizations = AppLocalizations.of(context);
    final rawCuisine = r.cuisine;
    final hasCuisine = rawCuisine != null && rawCuisine.trim().isNotEmpty;
    final cuisine = hasCuisine ? getLocalizedCuisine(rawCuisine, localizations) : null;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (auth == null) {
              ErrorUtils.showError(context, AppLocalizations.of(context)?.logInToViewProfiles ?? "Log in to view profiles");
              return;
            }
            // If viewing own profile, pass null to show edit functionality
            final isOwnProfile = auth!.me?["username"]?.toString() == r.authorUsername;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  auth: auth!,
                  apiClient: apiClient,
                  shoppingListController: shoppingListController,
                  username: isOwnProfile ? null : r.authorUsername,
                ),
              ),
            );
          },
          child: buildUserAvatar(
            context,
            r.authorAvatarUrl,
            r.authorUsername,
            radius: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: r.authorDisplayName ?? r.authorUsername,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextSpan(
                  text: " • $date",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Hashtag Pill widget
class _HashtagPill extends StatelessWidget {
  const _HashtagPill({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // Check if this tag matches a predefined category or dietary preference
    final category = recipeCategories.where((c) => c.tag == tag).firstOrNull;
    final dietary = dietaryPreferences.where((d) => d.tag == tag).firstOrNull;
    final displayLabel = category != null
        ? category.getLabel(localizations)
        : dietary != null
            ? dietary.getLabel(localizations)
            : tag;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        "#$displayLabel",
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Full Screen Image Viewer
class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<RecipeImage> images;
  final int initialIndex;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} / ${widget.images.length}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: RecipeImageWidget(
                imageUrl: image.url,
                fit: BoxFit.contain,
                placeholderSize: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Error View widget
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 80),
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Center(child: Text(localizations?.somethingWentWrong ?? "Something went wrong"));
          },
        ),
        const SizedBox(height: 12),
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return FilledButton(
                onPressed: () async => onRetry(),
                child: Text(localizations?.retry ?? "Retry"),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: IconButton(
          icon: Icon(icon, color: primary),
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}

class _NutritionPanel extends StatefulWidget {
  const _NutritionPanel({required this.recipeId, required this.apiClient});

  final String recipeId;
  final ApiClient apiClient;

  @override
  State<_NutritionPanel> createState() => _NutritionPanelState();
}

class _NutritionPanelState extends State<_NutritionPanel> {
  late final Future<RecipeNutrition?> _future;

  @override
  void initState() {
    super.initState();
    _future = RecipeApi(widget.apiClient).getNutrition(widget.recipeId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecipeNutrition?>(
      future: _future,
      builder: (context, snapshot) {
        final localizations = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;

        Widget content;

        if (snapshot.connectionState == ConnectionState.waiting) {
          content = Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: primary),
              ),
            ),
          );
        } else if (snapshot.hasError || snapshot.data == null) {
          content = Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              localizations?.nutritionUnavailable ?? "Nutrition data unavailable",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        } else {
          final n = snapshot.data!;
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Calories hero row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    n.calories.round().toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      localizations?.kcal ?? "kcal",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Macro row
              Row(
                children: [
                  _MacroChip(
                    label: localizations?.protein ?? "Protein",
                    value: "${n.protein.round()}${localizations?.gram ?? 'g'}",
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: localizations?.fat ?? "Fat",
                    value: "${n.fat.round()}${localizations?.gram ?? 'g'}",
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: localizations?.carbs ?? "Carbs",
                    value: "${n.carbs.round()}${localizations?.gram ?? 'g'}",
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: localizations?.sugar ?? "Sugar",
                    value: "${n.sugar.round()}${localizations?.gram ?? 'g'}",
                    color: Colors.teal.shade600,
                  ),
                ],
              ),
              if (n.isPartial) ...[
                const SizedBox(height: 10),
                Text(
                  localizations?.nutritionPartialNote(n.matched, n.total) ??
                      "Based on ${n.matched}/${n.total} ingredients",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          );
        }

        final nutrition = snapshot.data;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: nutrition != null
                ? () => _showNutritionBottomSheet(context, nutrition)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 18, color: primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          localizations?.nutritionFacts ?? "Nutrition Facts",
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (nutrition != null)
                        Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    ],
                  ),
                  content,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNutritionBottomSheet(BuildContext context, RecipeNutrition nutrition) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutritionBottomSheet(nutrition: nutrition),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionBottomSheet extends StatelessWidget {
  const _NutritionBottomSheet({required this.nutrition});

  final RecipeNutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final primary = theme.colorScheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Header with totals
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded, size: 20, color: primary),
                              const SizedBox(width: 8),
                              Text(
                                localizations?.nutritionFacts ?? 'Nutrition Facts',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                nutrition.calories.round().toString(),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  localizations?.kcal ?? 'kcal',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (nutrition.isPartial)
                                Text(
                                  localizations?.nutritionPartialNote(nutrition.matched, nutrition.total) ??
                                      '${nutrition.matched}/${nutrition.total} ingredients',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _MacroChip(label: localizations?.protein ?? 'Protein', value: '${nutrition.protein.round()}${localizations?.gram ?? 'g'}', color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              _MacroChip(label: localizations?.fat ?? 'Fat', value: '${nutrition.fat.round()}${localizations?.gram ?? 'g'}', color: Colors.orange.shade600),
                              const SizedBox(width: 8),
                              _MacroChip(label: localizations?.carbs ?? 'Carbs', value: '${nutrition.carbs.round()}${localizations?.gram ?? 'g'}', color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              _MacroChip(label: localizations?.sugar ?? 'Sugar', value: '${nutrition.sugar.round()}${localizations?.gram ?? 'g'}', color: Colors.teal.shade600),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(color: theme.colorScheme.outlineVariant),
                          const SizedBox(height: 4),
                          Text(
                            localizations?.perIngredient ?? 'Per ingredient',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.separated(
                  itemCount: nutrition.ingredients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _NutritionIngredientRow(
                      ingredient: nutrition.ingredients[index],
                      localizations: localizations,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NutritionIngredientRow extends StatelessWidget {
  const _NutritionIngredientRow({
    required this.ingredient,
    required this.localizations,
  });

  final NutritionIngredient ingredient;
  final AppLocalizations? localizations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = ingredient.isFound;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: found
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ingredient.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (ingredient.grams != null)
                Text(
                  '${ingredient.grams!.round()}${localizations?.gram ?? 'g'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              if (ingredient.grams != null && found && ingredient.calories != null)
                const SizedBox(width: 8),
              if (found && ingredient.calories != null)
                Text(
                  '${ingredient.calories!.round()} ${localizations?.kcal ?? "kcal"}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (!found) ...[
                if (ingredient.grams != null) const SizedBox(width: 8),
                Tooltip(
                  message: localizations?.nutritionNotFoundTooltip ?? 'We were not able to find the nutrition values for this ingredient in the USDA database',
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  preferBelow: false,
                  child: Icon(Icons.help_outline, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ],
          ),
          if (found) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _MiniMacro(label: localizations?.protein ?? 'P', value: '${(ingredient.protein ?? 0).round()}${localizations?.gram ?? 'g'}', color: Colors.blue.shade600),
                _MiniMacro(label: localizations?.fat ?? 'F', value: '${(ingredient.fat ?? 0).round()}${localizations?.gram ?? 'g'}', color: Colors.orange.shade600),
                _MiniMacro(label: localizations?.carbs ?? 'C', value: '${(ingredient.carbs ?? 0).round()}${localizations?.gram ?? 'g'}', color: Colors.green.shade600),
                _MiniMacro(label: localizations?.sugar ?? 'S', value: '${(ingredient.sugar ?? 0).round()}${localizations?.gram ?? 'g'}', color: Colors.teal.shade600),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              localizations?.nutritionNotFound ?? 'Data not available',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMacro extends StatelessWidget {
  const _MiniMacro({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
