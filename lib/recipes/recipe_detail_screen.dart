import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../screens/create_recipe_screen.dart";
import "../screens/profile_screen.dart";
import "../utils/ui_utils.dart";
import "comments_bottom_sheet.dart";
import "recipe_api.dart";
import "recipe_detail_controller.dart";
import "recipe_detail_models.dart";

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.apiClient,
    this.auth,
  });

  final String recipeId;
  final ApiClient apiClient;
  final AuthController? auth;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeDetailController c;
  late final RecipeApi recipeApi;
  bool _isLiking = false;
  bool _isBookmarking = false;
  bool? _viewerHasLiked;
  bool? _viewerHasBookmarked;
  int? _localLikes;
  int? _localBookmarks;
  int? _localComments;

  @override
  void initState() {
    super.initState();
    recipeApi = RecipeApi(widget.apiClient);
    c = RecipeDetailController(api: recipeApi, recipeId: widget.recipeId);
    c.addListener(_onChanged);
    c.load();
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
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final r = c.recipe;
    if (r == null || _isLiking) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to like recipes")),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to like recipe: $e")),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to bookmark recipes")),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to bookmark recipe: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBookmarking = false);
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, RecipeDetail recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Recipe"),
        content: Text(
          "Are you sure you want to delete \"${recipe.title}\"? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final recipeApi = RecipeApi(widget.apiClient);
      await recipeApi.deleteRecipe(recipe.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recipe deleted successfully")),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete recipe: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = c.recipe;
    final isOwner = widget.auth != null &&
        widget.auth!.isLoggedIn &&
        r != null &&
        widget.auth!.me?["username"]?.toString() == r.authorUsername;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: "Edit Recipe",
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: "Delete Recipe",
                onPressed: () => _showDeleteConfirmation(context, r),
              ),
            ),
          ],
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
                  ? const Center(child: Text("Not found"))
                  : RefreshIndicator(
                      onRefresh: c.refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Header Image
                          if (r.images.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _ImageGallery(
                                images: r.images,
                                counts: RecipeCounts(
                                  likes: _localLikes ?? r.counts.likes,
                                  comments: _localComments ?? r.counts.comments,
                                  bookmarks: _localBookmarks ?? r.counts.bookmarks,
                                ),
                                onLikeTap: _toggleLike,
                                onBookmarkTap: _toggleBookmark,
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
                                viewerHasLiked: _viewerHasLiked,
                                viewerHasBookmarked: _viewerHasBookmarked,
                                isLiking: _isLiking,
                                isBookmarking: _isBookmarking,
                              ),
                            ),
                          // Content
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    r.title,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // User Info Row
                                  _UserInfoRow(r: r, apiClient: widget.apiClient, auth: widget.auth),
                                  const SizedBox(height: 12),
                                  // Hashtag
                                  if (r.tags.isNotEmpty) ...[
                                    _HashtagPill(tag: r.tags.first),
                                    const SizedBox(height: 16),
                                  ],
                                  // Description
                                  if (r.description != null && r.description!.trim().isNotEmpty) ...[
                                    const _SectionTitle("Description"),
                                    const SizedBox(height: 8),
                                    Text(
                                      r.description!,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  // Accordion Sections
                                  _IngredientsCard(ingredients: r.ingredients),
                                  const SizedBox(height: 12),
                                  _StepsCard(steps: r.steps),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({required this.r, required this.apiClient, this.auth});
  final RecipeDetail r;
  final ApiClient apiClient;
  final AuthController? auth;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(r.createdAt);
    final cuisine = r.cuisine;
    final hasCuisine = cuisine != null && cuisine.trim().isNotEmpty;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (auth == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Log in to view profiles")),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  auth: auth!,
                  apiClient: apiClient,
                  username: r.authorUsername,
                ),
              ),
            );
          },
          child: buildUserAvatar(
            context,
            r.authorAvatarUrl,
            r.authorUsername,
            radius: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(
                "@${r.authorUsername}",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                " • $date",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (hasCuisine) ...[
                Text(
                  " • Cuisine: $cuisine",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HashtagPill extends StatelessWidget {
  const _HashtagPill({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        "# $tag",
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.ingredients});
  final List<RecipeIngredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Text("🥕", style: TextStyle(fontSize: 24)),
        title: Text("Ingredients (${ingredients.length})"),
        children: [
          const Divider(height: 1),
          ...ingredients.map((ing) {
            final qty = ing.quantity == null ? "" : "${ing.quantity}";
            final unit = ing.unit == null ? "" : " ${ing.unit}";
            final prefix = (qty.isEmpty && unit.isEmpty) ? "" : "$qty$unit • ";
            return ListTile(
              dense: true,
              title: Text("$prefix${ing.displayName}"),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});
  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Text("📋", style: TextStyle(fontSize: 24)),
        title: Text("Steps (${steps.length})"),
        children: [
          const Divider(height: 1),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final st = entry.value;
            return ListTile(
              leading: CircleAvatar(radius: 14, child: Text("$i")),
              title: Text(st.instruction),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}


class _EngagementMetricsOverlay extends StatelessWidget {
  const _EngagementMetricsOverlay({
    required this.counts,
    required this.onLikeTap,
    required this.onBookmarkTap,
    required this.onCommentTap,
    required this.viewerHasLiked,
    required this.viewerHasBookmarked,
    required this.isLiking,
    required this.isBookmarking,
  });

  final RecipeCounts counts;
  final VoidCallback onLikeTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onCommentTap;
  final bool viewerHasLiked;
  final bool viewerHasBookmarked;
  final bool isLiking;
  final bool isBookmarking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverlayIconButton(
            icon: Icons.favorite,
            count: counts.likes,
            isActive: viewerHasLiked,
            isLoading: isLiking,
            onTap: onLikeTap,
          ),
          const SizedBox(height: 12),
          _OverlayIconButton(
            icon: Icons.chat_bubble_outline,
            count: counts.comments,
            onTap: onCommentTap,
          ),
          const SizedBox(height: 12),
          _OverlayIconButton(
            icon: Icons.bookmark,
            count: counts.bookmarks,
            isActive: viewerHasBookmarked,
            isLoading: isBookmarking,
            onTap: onBookmarkTap,
          ),
        ],
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.onTap,
    this.count,
    this.isActive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isActive ? Theme.of(context).colorScheme.primary : Colors.white,
                      size: 24,
                    ),
                    if (count != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        "$count",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({
    required this.images,
    required this.counts,
    required this.onLikeTap,
    required this.onBookmarkTap,
    required this.onCommentTap,
    this.viewerHasLiked,
    this.viewerHasBookmarked,
    this.isLiking = false,
    this.isBookmarking = false,
  });
  final List<RecipeImage> images;
  final RecipeCounts counts;
  final VoidCallback onLikeTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onCommentTap;
  final bool? viewerHasLiked;
  final bool? viewerHasBookmarked;
  final bool isLiking;
  final bool isBookmarking;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openImageViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          images: widget.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 350,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final image = widget.images[index];
              return GestureDetector(
                onTap: () => _openImageViewer(index),
                child: Image.network(
                  buildImageUrl(image.url),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // Engagement metrics overlay (right, vertically centered)
          Positioned(
            top: 0,
            bottom: 0,
            right: 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: _EngagementMetricsOverlay(
                counts: widget.counts,
                onLikeTap: widget.onLikeTap,
                onBookmarkTap: widget.onBookmarkTap,
                onCommentTap: widget.onCommentTap,
                viewerHasLiked: widget.viewerHasLiked ?? false,
                viewerHasBookmarked: widget.viewerHasBookmarked ?? false,
                isLiking: widget.isLiking,
                isBookmarking: widget.isBookmarking,
              ),
            ),
          ),
          // Pagination indicators
          if (widget.images.length > 1)
            Positioned(
              bottom: 16,
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
                          : Colors.white.withOpacity(0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
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
              child: Image.network(
                buildImageUrl(image.url),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 64,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}


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
        const Center(child: Text("Something went wrong")),
        const SizedBox(height: 12),
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: () async => onRetry(),
            child: const Text("Retry"),
          ),
        ),
      ],
    );
  }
}
