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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          if (isOwner) ...[
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
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
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: AppLocalizations.of(context)?.deleteRecipe ?? "Delete Recipe",
                onPressed: () => _showDeleteConfirmation(context, r),
              ),
            ),
          ],
          // Show report button for non-owners who are logged in
          if (!isOwner && widget.auth?.isLoggedIn == true && r != null)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.white),
                tooltip: AppLocalizations.of(context)?.reportRecipe ?? "Report Recipe",
                onPressed: _handleReportRecipe,
              ),
            ),
        ],
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

          // Quick Info Bar
          if (recipe.cookingTimeMin != null || recipe.cookingTimeMax != null || recipe.difficulty != null) ...[
            _QuickInfoBar(
              cookingTimeMin: recipe.cookingTimeMin,
              cookingTimeMax: recipe.cookingTimeMax,
              difficulty: recipe.difficulty,
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

          // Tags
          if (recipe.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipe.tags.map((tag) => _HashtagPill(tag: tag)).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Description
          if (recipe.description != null && recipe.description!.trim().isNotEmpty) ...[
            Text(
              recipe.description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
          ],

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
      return "$cookingTimeMin-$cookingTimeMax $unit";
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
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (cookingTimeMin != null || cookingTimeMax != null)
          _InfoChip(
            icon: Icons.timer_outlined,
            label: _formatCookingTime(localizations),
          ),
        if (difficulty != null)
          _InfoChip(
            icon: Icons.signal_cellular_alt,
            label: _getLocalizedDifficulty(localizations),
            color: _getDifficultyColor(context),
          ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
          _VerticalDivider(),
          Expanded(
            child: _EngagementButton(
              icon: Icons.chat_bubble_outline,
              count: counts.comments,
              onTap: onCommentTap,
            ),
          ),
          _VerticalDivider(),
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
          _VerticalDivider(),
          Expanded(
            child: _EngagementButton(
              icon: Icons.send,
              count: shareCount,
              onTap: onShareTap,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitleWidget(
          text: "${localizations?.ingredients ?? "Ingredients"} (${ingredients.length})",
          variant: SectionTitleVariant.regular,
        ),
        const SizedBox(height: 12),
        ...ingredients.map((ing) => _IngredientTile(
          ingredient: ing,
          isChecked: checkedIds.contains(ing.id),
          isSelected: selectedIds.contains(ing.id),
          isSelectionMode: isSelectionMode,
          onToggle: () => onToggle(ing.id),
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

  String _formatIngredient() {
    final qty = ingredient.quantity == null ? "" : "${ingredient.quantity}";
    final unit = ingredient.unit == null ? "" : " ${ingredient.unit}";
    final prefix = (qty.isEmpty && unit.isEmpty) ? "" : "$qty$unit ";
    return "$prefix${ingredient.displayName}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCheckbox = !isSelectionMode;
    final showSelectionCheckbox = isSelectionMode;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelectionMode && isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (showCheckbox)
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (showSelectionCheckbox)
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatIngredient(),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  decoration: !isSelectionMode && isChecked ? TextDecoration.lineThrough : null,
                  color: !isSelectionMode && isChecked
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelectionMode && isSelected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
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
        )),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.step,
  });

  final int stepNumber;
  final RecipeStep step;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
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
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                step.instruction,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
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
            radius: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: r.authorDisplayName ?? r.authorUsername,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextSpan(
                  text: " • @${r.authorUsername} • $date",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                if (hasCuisine)
                  TextSpan(
                    text: " • $cuisine",
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
