import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../config.dart";
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

  @override
  Widget build(BuildContext context) {
    final r = c.recipe;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipe"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final commentCount = commentsController.comments.length;
            Navigator.of(context).pop(commentCount);
          },
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
                    ? const Center(child: Text("Not found"))
                    : RefreshIndicator(
                        onRefresh: c.refresh,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          children: [
                            if (r.images.isNotEmpty) ...[
                              _ImageGallery(images: r.images),
                              const SizedBox(height: 12),
                            ],
                            _Header(r: r),
                            const SizedBox(height: 12),
                            if (r.description != null && r.description!.trim().isNotEmpty) ...[
                              const _SectionTitle("Description"),
                              const SizedBox(height: 6),
                              Text(r.description!),
                              const SizedBox(height: 12),
                            ],
                            if (r.tags.isNotEmpty) ...[
                              const _SectionTitle("Tags"),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: r.tags.map((t) => Chip(label: Text(t))).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _CountsRow(counts: r.counts),
                            const SizedBox(height: 12),
                            _IngredientsCard(ingredients: r.ingredients),
                            const SizedBox(height: 12),
                            _StepsCard(steps: r.steps),
                            const SizedBox(height: 12),
                            _CommentsSection(
                              commentsController: commentsController,
                              auth: widget.auth,
                            ),
                          ],
                        ),
                      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.r});
  final RecipeDetail r;

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(r.createdAt);

    final cuisine = r.cuisine; // helps avoid any nullable weirdness
    final hasCuisine = cuisine != null && cuisine.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                r.authorAvatarUrl != null && r.authorAvatarUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: NetworkImage(_buildImageUrl(r.authorAvatarUrl!)),
                        onBackgroundImageError: (exception, stackTrace) {
                          // Image failed to load, will show child as fallback
                        },
                        child: null,
                      )
                    : CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          r.authorUsername.isNotEmpty
                              ? r.authorUsername[0].toUpperCase()
                              : "?",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                const SizedBox(width: 6),
                Text("@${r.authorUsername} • $date", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (hasCuisine) ...[
              const SizedBox(height: 6),
              Text("Cuisine: $cuisine", style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _MiniStat(icon: Icons.favorite, label: "Likes", value: counts.likes),
            const SizedBox(width: 16),
            _MiniStat(icon: Icons.chat_bubble_outline, label: "Comments", value: counts.comments),
            const SizedBox(width: 16),
            _MiniStat(icon: Icons.bookmark, label: "Bookmarks", value: counts.bookmarks),
          ],
        ),
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
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text("$value"),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
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
        initiallyExpanded: true,
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
        initiallyExpanded: true,
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

String _buildImageUrl(String relativeUrl) {
  if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
    return relativeUrl;
  }
  return "${Config.apiBaseUrl}$relativeUrl";
}

String _formatDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final localDate = date.toLocal();
  return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year}';
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(
              height: 300,
              child: PageView.builder(
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
                      _buildImageUrl(image.url),
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
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 12,
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
                _buildImageUrl(image.url),
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

class _CommentsSection extends StatefulWidget {
  const _CommentsSection({
    required this.commentsController,
    this.auth,
  });

  final CommentsController commentsController;
  final AuthController? auth;

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
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

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text("Comments (${widget.commentsController.comments.length})"),
        children: [
          const Divider(height: 1),
          if (isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        counterText: "",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSubmitting)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _submitComment,
                      icon: const Icon(Icons.send_rounded),
                      tooltip: "Post comment",
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Log in to comment",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ),
            const Divider(height: 1),
          ],
          if (widget.commentsController.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.commentsController.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Error loading comments: ${widget.commentsController.error}",
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else if (widget.commentsController.comments.isEmpty)
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
            ...widget.commentsController.comments.map((comment) {
              final date = _formatDate(comment.createdAt);
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
