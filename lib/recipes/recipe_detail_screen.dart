import "dart:ui";

import "package:flutter/material.dart";

import "../analytics/analytics_service.dart";
import "../feed/feed_models.dart" show FeedItem;
import "../search/search_models.dart";
import "../widgets/common/skeletons.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../auth/require_account.dart";
import "../collections/add_to_collection_bottom_sheet.dart";
import "../localization/app_localizations.dart";
import "../screens/create_recipe_screen.dart";
import "../screens/profile_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../services/push_prompt_service.dart";
import "../utils/error_utils.dart";
import "../utils/ui_utils.dart";
import "../widgets/streak_celebration_overlay.dart";
import "../widgets/sharing/follower_selection_bottom_sheet.dart";
import "../reports/report_bottom_sheet.dart";
import "../reports/report_models.dart";
import "comments_bottom_sheet.dart";
import "liked_by_bottom_sheet.dart";
import "recipe_api.dart";
import "recipe_detail_controller.dart";
import "../theme/app_tokens.dart";
import "../widgets/common/app_bottom_sheet.dart";
import "../widgets/empty_state_widget.dart";
import "recipe_detail_models.dart";
import "add_to_shopping_list_sheet.dart";
import "cooking_mode_screen.dart";
import "ingredient_ticks_store.dart";
import "recipe_detail_parts.dart";
import "recipe_sharing_controller.dart";

/// What the screen that opens a recipe already knows about it (a feed card,
/// a grid tile, a search result), shown while the full recipe loads.
class RecipeSeed {
  const RecipeSeed({
    required this.title,
    required this.authorUsername,
    this.imageUrls = const [],
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.createdAt,
    this.description,
    this.tags = const [],
    this.cookingTimeMin,
    this.cookingTimeMax,
    this.difficulty,
    this.servingSize,
    this.likes,
    this.comments,
    this.bookmarks,
    this.shares,
    this.viewerHasLiked = false,
    this.viewerHasBookmarked = false,
  });

  final String title;
  final String authorUsername;
  final List<String> imageUrls;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final DateTime? createdAt;
  final String? description;
  final List<String> tags;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final String? difficulty;
  final int? servingSize;

  /// Counts, when the opener has them (feed items do, search results don't).
  final int? likes;
  final int? comments;
  final int? bookmarks;
  final int? shares;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;

  factory RecipeSeed.fromFeedItem(FeedItem item) => RecipeSeed(
        title: item.title,
        authorUsername: item.authorUsername,
        imageUrls: [for (final image in item.images) image.url],
        authorDisplayName: item.authorDisplayName,
        authorAvatarUrl: item.authorAvatarUrl,
        createdAt: item.createdAt,
        description: item.description,
        tags: item.tags,
        cookingTimeMin: item.cookingTimeMin,
        cookingTimeMax: item.cookingTimeMax,
        difficulty: item.difficulty,
        servingSize: item.servingSize,
        likes: item.likes,
        comments: item.comments,
        bookmarks: item.bookmarks,
        shares: item.shares,
        viewerHasLiked: item.viewerHasLiked,
        viewerHasBookmarked: item.viewerHasBookmarked,
      );

  factory RecipeSeed.fromSearchResult(SearchResult result) => RecipeSeed(
        title: result.title,
        authorUsername: result.authorUsername,
        imageUrls: [if (result.imageUrl != null) result.imageUrl!],
        authorDisplayName: result.authorDisplayName,
        authorAvatarUrl: result.authorAvatarUrl,
        createdAt: result.createdAt,
        cookingTimeMin: result.cookingTimeMin,
        cookingTimeMax: result.cookingTimeMax,
        difficulty: result.difficulty,
      );
}

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.apiClient,
    this.auth,
    required this.shoppingListController,
    this.openComments = false,
    this.seed,
  });

  final String recipeId;
  final ApiClient apiClient;
  final AuthController? auth;
  final ShoppingListController shoppingListController;
  final bool openComments;

  /// Shown right away while the full recipe loads, so the page doesn't open
  /// to a blank spinner. Null where the opener has nothing (notifications,
  /// the shopping list, links).
  final RecipeSeed? seed;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeDetailController c;
  late final RecipeApi recipeApi;
  late final RecipeSharingController _sharingController;
  bool _isLiking = false;
  bool _isBookmarking = false;
  bool _isCooking = false;
  bool _cookedThisSession = false;
  bool _commentsOpened = false;
  bool? _viewerHasLiked;
  bool? _viewerHasBookmarked;
  int? _localLikes;
  int? _localBookmarks;
  int? _localComments;
  /// Ingredients ticked off ("I have it" / done), kept per recipe on the
  /// phone (IngredientTicksStore) and shared with cooking mode.
  Set<String> _tickedIngredients = {};
  bool _viewContentLogged = false;
  int? _selectedServings;

  @override
  void initState() {
    super.initState();
    recipeApi = RecipeApi(widget.apiClient);
    c = RecipeDetailController(api: recipeApi, recipeId: widget.recipeId);
    c.addListener(_onChanged);
    c.load();
    IngredientTicksStore.load(widget.recipeId).then((ticks) {
      if (mounted && ticks.isNotEmpty) setState(() => _tickedIngredients = ticks);
    });

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
      AnalyticsService().logRecipeView(recipe.id, cuisineType: recipe.cuisine);
    }
    if (widget.openComments && !_commentsOpened && c.recipe != null && mounted) {
      _commentsOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showCommentsBottomSheet(
            context: context,
            recipeId: widget.recipeId,
            apiClient: widget.apiClient,
            auth: widget.auth,
          );
        }
      });
    }
    if (mounted) {
      setState(() {
        _localLikes = null;
        _localBookmarks = null;
        _localComments = null;
        _viewerHasLiked = c.recipe?.viewerHasLiked;
        _viewerHasBookmarked = c.recipe?.viewerHasBookmarked;
        _selectedServings ??= c.recipe?.servingSize;
        if (c.recipe?.cookedToday == true) {
          _cookedThisSession = true;
        }
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
      _tickedIngredients = {..._tickedIngredients};
      if (!_tickedIngredients.remove(id)) _tickedIngredients.add(id);
    });
    IngredientTicksStore.save(widget.recipeId, _tickedIngredients);
  }

  void _setTicks(Set<String> ticks) {
    setState(() => _tickedIngredients = {...ticks});
    IngredientTicksStore.save(widget.recipeId, _tickedIngredients);
  }

  double get _scaleFactor {
    final servings = c.recipe?.servingSize;
    final selected = _selectedServings;
    return (servings != null && servings > 0 && selected != null) ? selected / servings : 1.0;
  }

  Future<void> _startCooking() async {
    final r = c.recipe;
    if (r == null) return;
    final scale = _scaleFactor;
    final madeIt = await openCookingMode(
      context,
      title: r.title,
      steps: [for (final step in r.steps) step.instruction],
      ingredients: [for (final ing in r.ingredients) RecipeIngredientLine.fromIngredient(ing, scale)],
      tickedIds: _tickedIngredients,
      onTicksChanged: _setTicks,
      canMarkCooked: widget.auth != null && !_cookedThisSession,
    );
    if (madeIt && mounted) await _cookRecipe();
  }

  Future<void> _addToShoppingList() async {
    final r = c.recipe;
    if (r == null) return;
    await showAddToShoppingListSheet(
      context: context,
      recipe: r,
      scaleFactor: _scaleFactor,
      tickedIds: _tickedIngredients,
      shoppingListController: widget.shoppingListController,
      apiClient: widget.apiClient,
      auth: widget.auth,
    );
  }

  /// Login-tier gate for this screen. After a fresh sign-in the recipe is
  /// reloaded, so viewer flags (liked, saved, cooked today) are the account's
  /// and not the guest's all-false ones. Returns false if the user backed out.
  Future<bool> _requireAccount(AccountReason reason) async {
    final auth = widget.auth;
    if (auth == null) return false;
    final wasGuest = !auth.isLoggedIn;
    if (!await requireAccount(context, auth, reason)) return false;
    if (wasGuest && mounted) await c.reloadQuietly();
    return mounted;
  }

  Future<bool> _handleAuthError(Object e, AccountReason reason) async {
    final auth = widget.auth;
    return auth != null && await handleAuthError(context, auth, e, reason);
  }

  Future<void> _toggleLike() async {
    if (c.recipe == null || _isLiking) return;
    final wasGuest = !(widget.auth?.isLoggedIn ?? false);
    if (!await _requireAccount(AccountReason.like)) return;
    // Just signed in to an account that already likes this: nothing to do.
    if (wasGuest && _viewerHasLiked == true) return;
    final r = c.recipe;
    if (r == null) return;

    setState(() => _isLiking = true);

    try {
      final wasLiked = _viewerHasLiked ?? false;
      if (wasLiked) {
        await recipeApi.unlike(r.id);
        AnalyticsService().logUnlike(r.id);
      } else {
        await recipeApi.like(r.id);
        AnalyticsService().logLike(r.id);
        if (mounted) {
          PushPromptService().onLikeCompleted(context, widget.apiClient);
        }
      }
      if (!mounted) return;
      final base = _localLikes ?? r.counts.likes;
      setState(() {
        _viewerHasLiked = !wasLiked;
        _localLikes = base + (wasLiked ? -1 : 1);
      });
    } catch (e) {
      if (mounted && !await _handleAuthError(e, AccountReason.like) && mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    if (c.recipe == null || _isBookmarking) return;
    final wasGuest = !(widget.auth?.isLoggedIn ?? false);
    if (!await _requireAccount(AccountReason.save)) return;
    if (wasGuest && _viewerHasBookmarked == true) return;
    final r = c.recipe;
    if (r == null) return;

    setState(() => _isBookmarking = true);

    try {
      final wasBookmarked = _viewerHasBookmarked ?? false;
      if (wasBookmarked) {
        await recipeApi.unbookmark(r.id);
        AnalyticsService().logRecipeUnsave(r.id);
      } else {
        await recipeApi.bookmark(r.id);
        AnalyticsService().logRecipeSave(r.id);
        if (mounted) {
          PushPromptService().onSaveCompleted(context, widget.apiClient);
        }
      }
      if (!mounted) return;
      final base = _localBookmarks ?? r.counts.bookmarks;
      setState(() {
        _viewerHasBookmarked = !wasBookmarked;
        _localBookmarks = base + (wasBookmarked ? -1 : 1);
      });
    } catch (e) {
      if (mounted && !await _handleAuthError(e, AccountReason.save) && mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isBookmarking = false);
      }
    }
  }

  Future<void> _cookRecipe() async {
    if (c.recipe == null || _isCooking || _cookedThisSession) return;
    if (!await _requireAccount(AccountReason.cook)) return;
    // The reload after sign-in may show it was already cooked today.
    final r = c.recipe;
    if (r == null || _cookedThisSession) return;

    setState(() => _isCooking = true);

    try {
      final result = await recipeApi.cookRecipe(r.id);
      final streakDays = (result["streak_days"] as num?)?.toInt() ?? 1;
      final isNewRecord = result["is_new_record"] as bool? ?? false;
      final firstCookToday = result["first_cook_today"] as bool? ?? true;

      AnalyticsService().logRecipeCook(r.id);

      if (!mounted) return;
      setState(() {
        _cookedThisSession = true;
        _tickedIngredients = {};
      });
      IngredientTicksStore.clear(r.id);

      if (!firstCookToday) return;

      await showStreakCelebration(
        context,
        streakDays: streakDays,
        isNewRecord: isNewRecord,
      );
    } catch (e) {
      if (mounted && !await _handleAuthError(e, AccountReason.cook) && mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isCooking = false);
      }
    }
  }

  Future<void> _onBookmarkLongPress() async {
    if (c.recipe == null) return;
    if (!await _requireAccount(AccountReason.collections)) return;
    final r = c.recipe;
    if (r == null || !mounted) return;
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
    if (!await _requireAccount(AccountReason.share)) return;

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

    if (!await _requireAccount(AccountReason.report) || !mounted) return;
    // Signing in may reveal this is the viewer's own recipe.
    if (widget.auth?.me?["username"]?.toString() == r.authorUsername) return;

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
              color: AppTokens.of(context).bg.withValues(alpha: 0.5),
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
                    if (!isOwner && widget.auth != null && r != null)
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
          ? (c.recipe == null && widget.seed != null
              ? _SeededLoadingView(seed: widget.seed!)
              : const Center(child: CircularProgressIndicator()))
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
                  : RecipeDetailLayout(
                      hero: RecipeHeroImages(
                        count: r.images.length,
                        onImageTap: (index) => _openImageViewer(index, r.images),
                        imageBuilder: (context, index, height) => RecipeImageWidget(
                          imageUrl: r.images[index].url,
                          width: double.infinity,
                          height: height,
                          fit: BoxFit.cover,
                        ),
                      ),
                      sheetChild: (scrollController) => RefreshIndicator(
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
                                    isCooking: _isCooking,
                                    cookedThisSession: _cookedThisSession,
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
                                    onCookTap: _cookRecipe,
                                    tickedIngredients: _tickedIngredients,
                                    onToggleIngredient: _toggleIngredient,
                                    onClearTicks: () => _setTicks(const {}),
                                    onAddToShoppingList: _addToShoppingList,
                                    onStartCooking: _startCooking,
                                    selectedServings: _selectedServings,
                                    onServingsChanged: (v) => setState(() => _selectedServings = v),
                                    isOwner: isOwner,
                                    shareCount: r.counts.shares,
                                    onShareTap: _onShareTap,
                                  ),
                                ),
                              ),
                    ),
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

// Content Body widget: the published recipe in the shared layout
// (recipe_detail_parts.dart), with the page's live counts and actions.
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
    required this.isCooking,
    required this.cookedThisSession,
    required this.onLikeTap,
    this.onLikeLongPress,
    required this.onBookmarkTap,
    this.onBookmarkLongPress,
    required this.onCommentTap,
    required this.onCookTap,
    required this.tickedIngredients,
    required this.onToggleIngredient,
    required this.onClearTicks,
    required this.onAddToShoppingList,
    required this.onStartCooking,
    this.selectedServings,
    required this.onServingsChanged,
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
  final bool isCooking;
  final bool cookedThisSession;
  final VoidCallback onLikeTap;
  final VoidCallback? onLikeLongPress;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback onCommentTap;
  final VoidCallback onCookTap;
  final Set<String> tickedIngredients;
  final ValueChanged<String> onToggleIngredient;
  final VoidCallback onClearTicks;
  final VoidCallback onAddToShoppingList;
  final VoidCallback onStartCooking;
  final int? selectedServings;
  final ValueChanged<int> onServingsChanged;
  final bool isOwner;
  final int shareCount;
  final VoidCallback onShareTap;

  void _openAuthor(BuildContext context) {
    if (auth == null) {
      ErrorUtils.showError(context, AppLocalizations.of(context)?.logInToViewProfiles ?? "Log in to view profiles");
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          auth: auth!,
          apiClient: apiClient,
          shoppingListController: shoppingListController,
          username: recipe.authorUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servings = recipe.servingSize;
    final scaleFactor = (servings != null && servings > 0 && selectedServings != null)
        ? selectedServings! / servings
        : 1.0;

    return RecipeDetailContent(
      title: recipe.title,
      authorRow: RecipeAuthorRow(
        username: recipe.authorUsername,
        displayName: recipe.authorDisplayName,
        avatarUrl: recipe.authorAvatarUrl,
        date: recipe.createdAt,
        onTap: () => _openAuthor(context),
      ),
      description: recipe.description,
      engagement: RecipeEngagementBar(
        likes: counts.likes,
        comments: counts.comments,
        bookmarks: counts.bookmarks,
        shares: shareCount,
        viewerHasLiked: viewerHasLiked,
        viewerHasBookmarked: viewerHasBookmarked,
        isLiking: isLiking,
        isBookmarking: isBookmarking,
        onLikeTap: onLikeTap,
        onLikeLongPress: onLikeLongPress,
        onCommentTap: onCommentTap,
        onBookmarkTap: onBookmarkTap,
        onBookmarkLongPress: onBookmarkLongPress,
        onShareTap: onShareTap,
      ),
      quickInfo: RecipeQuickInfoBar.hasContent(
        cookingTimeMin: recipe.cookingTimeMin,
        cookingTimeMax: recipe.cookingTimeMax,
        difficulty: recipe.difficulty,
        servings: servings,
      )
          ? RecipeQuickInfoBar(
              cookingTimeMin: recipe.cookingTimeMin,
              cookingTimeMax: recipe.cookingTimeMax,
              difficulty: recipe.difficulty,
              originalServings: servings,
              selectedServings: selectedServings,
              onServingsChanged: onServingsChanged,
            )
          : null,
      startCooking: recipe.steps.isEmpty ? null : RecipeStartCookingButton(onPressed: onStartCooking),
      tags: recipe.tags,
      ingredients: recipe.ingredients.isEmpty
          ? null
          : RecipeIngredientsSection(
              lines: [
                for (final ing in recipe.ingredients) RecipeIngredientLine.fromIngredient(ing, scaleFactor),
              ],
              tickedIds: tickedIngredients,
              onToggle: onToggleIngredient,
              onClearTicks: onClearTicks,
              onAddToShoppingList: onAddToShoppingList,
            ),
      nutrition: _NutritionPanel(
        recipeId: recipe.id,
        apiClient: apiClient,
        scaleFactor: (servings != null && servings > 0) ? 1.0 / servings : 1.0,
        isPerServing: servings != null,
      ),
      steps: [for (final step in recipe.steps) step.instruction],
      // "Made It!" cook button (guests are asked to sign in on tap)
      footer: auth == null
          ? null
          : _MadeItButton(
              isCooking: isCooking,
              cookedThisSession: cookedThisSession,
              onTap: onCookTap,
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

/// The page laid out from a [RecipeSeed] while the recipe loads: photos,
/// title, author, description, quick info and tags right away, with
/// placeholders where the ingredients and steps will be. Nothing is tappable
/// until the real recipe arrives.
class _SeededLoadingView extends StatelessWidget {
  const _SeededLoadingView({required this.seed});

  final RecipeSeed seed;

  @override
  Widget build(BuildContext context) {
    final hasCounts = seed.likes != null;
    return IgnorePointer(
      child: RecipeDetailLayout(
        hero: RecipeHeroImages(
          count: seed.imageUrls.length,
          imageBuilder: (context, index, height) => RecipeImageWidget(
            imageUrl: seed.imageUrls[index],
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          ),
        ),
        sheetChild: (scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: RecipeDetailContent(
            title: seed.title,
            authorRow: RecipeAuthorRow(
              username: seed.authorUsername,
              displayName: seed.authorDisplayName,
              avatarUrl: seed.authorAvatarUrl,
              date: seed.createdAt ?? DateTime.now(),
            ),
            description: seed.description,
            engagement: hasCounts
                ? RecipeEngagementBar(
                    likes: seed.likes ?? 0,
                    comments: seed.comments ?? 0,
                    bookmarks: seed.bookmarks ?? 0,
                    shares: seed.shares ?? 0,
                    viewerHasLiked: seed.viewerHasLiked,
                    viewerHasBookmarked: seed.viewerHasBookmarked,
                  )
                : null,
            quickInfo: RecipeQuickInfoBar.hasContent(
              cookingTimeMin: seed.cookingTimeMin,
              cookingTimeMax: seed.cookingTimeMax,
              difficulty: seed.difficulty,
              servings: seed.servingSize,
            )
                ? RecipeQuickInfoBar(
                    cookingTimeMin: seed.cookingTimeMin,
                    cookingTimeMax: seed.cookingTimeMax,
                    difficulty: seed.difficulty,
                    originalServings: seed.servingSize,
                  )
                : null,
            tags: seed.tags,
            ingredients: const _IngredientsPlaceholder(),
          ),
        ),
      ),
    );
  }
}

/// Pulsing stand-ins for the ingredients header and rows.
class _IngredientsPlaceholder extends StatelessWidget {
  const _IngredientsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(width: 140, height: 22),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              child: SkeletonBox(width: double.infinity, height: 52),
            ),
          ),
      ],
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
    return ErrorStateWidget(message: error, onRetry: () => onRetry());
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
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: t.card,
        shape: const CircleBorder(),
        elevation: 0,
        child: IconButton(
          icon: Icon(icon, color: t.brandInk),
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}

class _MadeItButton extends StatelessWidget {
  const _MadeItButton({
    required this.isCooking,
    required this.cookedThisSession,
    required this.onTap,
  });

  final bool isCooking;
  final bool cookedThisSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDone = cookedThisSession;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: (isCooking || isDone) ? null : onTap,
        icon: isCooking
            // The button is disabled meanwhile: default (primary) spinner.
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(isDone ? Icons.check_circle_outline : Icons.local_fire_department_rounded),
        label: Text(
          isDone
              ? (l?.alreadyCookedToday ?? "Cooked today ✓")
              : (l?.madeIt ?? "გავაკეთე! 🔥"),
        ),
        // Not cooked yet: the theme's primary button.
        style: isDone
            ? FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )
            : null,
      ),
    );
  }
}

class _NutritionPanel extends StatefulWidget {
  const _NutritionPanel({
    required this.recipeId,
    required this.apiClient,
    this.scaleFactor = 1.0,
    this.isPerServing = false,
  });

  final String recipeId;
  final ApiClient apiClient;
  final double scaleFactor;
  final bool isPerServing;

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
          final s = widget.scaleFactor;
          final calories = (n.calories * s).round();
          final protein = (n.protein * s).round();
          final fat = (n.fat * s).round();
          final carbs = (n.carbs * s).round();
          final sugar = (n.sugar * s).round();
          final gram = localizations?.gram ?? 'g';
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Calories hero row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    calories.toString(),
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
                  if (widget.isPerServing) ...[
                    const Spacer(),
                    Text(
                      localizations?.perServing ?? "per serving",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Macro row
              Row(
                children: [
                  _MacroChip(
                    label: localizations?.protein ?? "Protein",
                    value: "$protein$gram",
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: localizations?.fat ?? "Fat",
                    value: "$fat$gram",
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: localizations?.carbs ?? "Carbs",
                    value: "$carbs$gram",
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: localizations?.sugar ?? "Sugar",
                    value: "$sugar$gram",
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
                ? () => _showNutritionBottomSheet(context, nutrition, widget.scaleFactor, widget.isPerServing)
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

  void _showNutritionBottomSheet(BuildContext context, RecipeNutrition nutrition, double scaleFactor, bool isPerServing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutritionBottomSheet(nutrition: nutrition, scaleFactor: scaleFactor, isPerServing: isPerServing),
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
  const _NutritionBottomSheet({
    required this.nutrition,
    this.scaleFactor = 1.0,
    this.isPerServing = false,
  });

  final RecipeNutrition nutrition;
  final double scaleFactor;
  final bool isPerServing;

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
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: sheetTopRadius,
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 4),
                      child: SheetHandle(),
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
                          Builder(builder: (context) {
                            final gram = localizations?.gram ?? 'g';
                            final calories = (nutrition.calories * scaleFactor).round();
                            final protein = (nutrition.protein * scaleFactor).round();
                            final fat = (nutrition.fat * scaleFactor).round();
                            final carbs = (nutrition.carbs * scaleFactor).round();
                            final sugar = (nutrition.sugar * scaleFactor).round();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      calories.toString(),
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
                                    if (isPerServing)
                                      Text(
                                        localizations?.perServing ?? 'per serving',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else if (nutrition.isPartial)
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
                                if (isPerServing && nutrition.isPartial) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    localizations?.nutritionPartialNote(nutrition.matched, nutrition.total) ??
                                        '${nutrition.matched}/${nutrition.total} ingredients',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _MacroChip(label: localizations?.protein ?? 'Protein', value: '$protein$gram', color: Colors.blue.shade600),
                                    const SizedBox(width: 8),
                                    _MacroChip(label: localizations?.fat ?? 'Fat', value: '$fat$gram', color: Colors.orange.shade600),
                                    const SizedBox(width: 8),
                                    _MacroChip(label: localizations?.carbs ?? 'Carbs', value: '$carbs$gram', color: Colors.green.shade600),
                                    const SizedBox(width: 8),
                                    _MacroChip(label: localizations?.sugar ?? 'Sugar', value: '$sugar$gram', color: Colors.teal.shade600),
                                  ],
                                ),
                              ],
                            );
                          }),
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
                      scaleFactor: scaleFactor,
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
    this.scaleFactor = 1.0,
  });

  final NutritionIngredient ingredient;
  final AppLocalizations? localizations;
  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = ingredient.isFound;
    final gram = localizations?.gram ?? 'g';

    final grams = ingredient.grams != null ? (ingredient.grams! * scaleFactor).round() : null;
    final calories = ingredient.calories != null ? (ingredient.calories! * scaleFactor).round() : null;
    final protein = ((ingredient.protein ?? 0) * scaleFactor).round();
    final fat = ((ingredient.fat ?? 0) * scaleFactor).round();
    final carbs = ((ingredient.carbs ?? 0) * scaleFactor).round();
    final sugar = ((ingredient.sugar ?? 0) * scaleFactor).round();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: found
            ? theme.colorScheme.surfaceContainerHighest
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
              if (grams != null)
                Text(
                  '$grams$gram',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              if (grams != null && found && calories != null)
                const SizedBox(width: 8),
              if (found && calories != null)
                Text(
                  '$calories ${localizations?.kcal ?? "kcal"}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (!found) ...[
                if (grams != null) const SizedBox(width: 8),
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
                _MiniMacro(label: localizations?.protein ?? 'P', value: '$protein$gram', color: Colors.blue.shade600),
                _MiniMacro(label: localizations?.fat ?? 'F', value: '$fat$gram', color: Colors.orange.shade600),
                _MiniMacro(label: localizations?.carbs ?? 'C', value: '$carbs$gram', color: Colors.green.shade600),
                _MiniMacro(label: localizations?.sugar ?? 'S', value: '$sugar$gram', color: Colors.teal.shade600),
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
