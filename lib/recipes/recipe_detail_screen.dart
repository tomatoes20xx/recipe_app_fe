import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../screens/create_recipe_screen.dart";
import "../utils/ui_utils.dart";
import "comments_controller.dart";
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
  late final CommentsController commentsController;

  @override
  void initState() {
    super.initState();
    final recipeApi = RecipeApi(widget.apiClient);
    c = RecipeDetailController(api: recipeApi, recipeId: widget.recipeId);
    commentsController = CommentsController(recipeApi: recipeApi, recipeId: widget.recipeId);
    c.addListener(_onChanged);
    commentsController.addListener(_onChanged);
    c.load();
    commentsController.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    commentsController.removeListener(_onChanged);
    c.dispose();
    commentsController.dispose();
    super.dispose();
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
            onPressed: () {
              final commentCount = commentsController.comments.length;
              Navigator.of(context).pop(commentCount);
            },
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
                              child: _ImageGallery(images: r.images),
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
                                  _UserInfoRow(r: r),
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
                                  // Engagement Metrics
                                  _CountsRow(counts: r.counts),
                                  const SizedBox(height: 16),
                                  // Accordion Sections
                                  _IngredientsCard(ingredients: r.ingredients),
                                  const SizedBox(height: 12),
                                  _StepsCard(steps: r.steps),
                                  const SizedBox(height: 12),
                                  _CommentsCard(
                                    commentsController: commentsController,
                                    auth: widget.auth,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
      // Comment Input at Bottom
      bottomNavigationBar: r != null && widget.auth?.isLoggedIn == true
          ? _CommentInputBar(
              commentsController: commentsController,
              auth: widget.auth,
            )
          : null,
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({required this.r});
  final RecipeDetail r;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(r.createdAt);
    final cuisine = r.cuisine;
    final hasCuisine = cuisine != null && cuisine.trim().isNotEmpty;

    return Row(
      children: [
        buildUserAvatar(
          context,
          r.authorAvatarUrl,
          r.authorUsername,
          radius: 16,
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

class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.counts});
  final RecipeCounts counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _MiniStat(icon: Icons.favorite, label: "Likes", value: counts.likes),
          const SizedBox(width: 24),
          _MiniStat(icon: Icons.chat_bubble_outline, label: "Comments", value: counts.comments),
          const SizedBox(width: 24),
          _MiniStat(icon: Icons.bookmark, label: "Bookmarks", value: counts.bookmarks),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 6),
        Text(
          "$value $label",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
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


class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.images});
  final List<RecipeImage> images;

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

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({
    required this.commentsController,
    this.auth,
  });

  final CommentsController commentsController;
  final AuthController? auth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Text("💬", style: TextStyle(fontSize: 24)),
        title: Text("Comments (${commentsController.comments.length})"),
        children: [
          const Divider(height: 1),
          if (commentsController.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (commentsController.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Error loading comments: ${commentsController.error}",
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else if (commentsController.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "No comments yet. Be the first to comment!",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            )
          else
            ...commentsController.comments.map((comment) {
              final date = formatDate(comment.createdAt);
              return ListTile(
                dense: true,
                title: Text(comment.content),
                subtitle: Text(
                  "@${comment.authorUsername} • $date",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatefulWidget {
  const _CommentInputBar({
    required this.commentsController,
    this.auth,
  });

  final CommentsController commentsController;
  final AuthController? auth;

  @override
  State<_CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<_CommentInputBar> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (!(widget.auth?.isLoggedIn ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to comment")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.commentsController.addComment(content);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post comment: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = widget.auth?.isLoggedIn ?? false;
    if (!isLoggedIn) return const SizedBox.shrink();

    final userAvatar = widget.auth?.me?["avatar_url"]?.toString();
    final username = widget.auth?.me?["username"]?.toString() ?? "";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            buildUserAvatar(
              context,
              userAvatar,
              username,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLines: null,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: "Write a comment...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  counterText: "",
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSubmitting ? null : _submitComment,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              tooltip: "Post comment",
            ),
          ],
        ),
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
