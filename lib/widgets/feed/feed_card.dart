import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:google_fonts/google_fonts.dart";

import "../../analytics/analytics_service.dart";
import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../auth/require_account.dart";
import "../../constants/enums.dart";
import "../../feed/feed_controller.dart";
import "../../feed/feed_models.dart";
import "../../localization/app_localizations.dart";
import "../../recipes/comments_bottom_sheet.dart";
import "../../reports/report_bottom_sheet.dart";
import "../../reports/report_models.dart";
import "../../screens/profile_screen.dart";
import "../../search/filter_terms.dart";
import "../../shopping/shopping_list_controller.dart";
import "../../theme/app_tokens.dart";
import "../../utils/ui_utils.dart";
import "feed_actions.dart";

const _likeRed = Color(0xFFE53935);

// The theme's Nunito (GoogleFonts.nunitoTextTheme) registers each weight as its
// own font family, so a bare `fontWeight: w700` on Latin text stays regular.
// Bold Latin text here goes through GoogleFonts.nunito to get the 700 file;
// Georgian falls back to Noto Sans Georgian either way.

/// Recipe card in the Home feed list: author header, full-width photo, title,
/// time / servings / category, then like, comment and save.
class FeedCard extends StatefulWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.sort,
    required this.feed,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
    this.onActionCompleted,
    this.position,
  });

  final FeedItem item;
  final FeedSort sort;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;
  final VoidCallback? onActionCompleted;
  final int? position;

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().logFeedCardImpression(widget.item.id, position: widget.position);
  }

  bool get _isOwnRecipe => widget.auth.me?["username"]?.toString() == widget.item.authorUsername;

  Future<void> _showMoreSheet() async {
    final t = AppTokens.of(context);
    final action = await showModalBottomSheet<_MoreAction>(
      context: context,
      backgroundColor: t.sheet,
      barrierColor: t.scrim,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MoreSheet(showReport: !_isOwnRecipe),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _MoreAction.collections:
        final changed = await openCollectionsFromFeed(
          context,
          feed: widget.feed,
          recipeId: widget.item.id,
          auth: widget.auth,
          apiClient: widget.apiClient,
        );
        if (changed) widget.onActionCompleted?.call();
      case _MoreAction.report:
        if (!await requireAccount(context, widget.auth, AccountReason.report) || !mounted) return;
        // Signing in may reveal this is the viewer's own recipe.
        if (_isOwnRecipe) return;
        await showReportBottomSheet(
          context: context,
          targetType: ReportTargetType.recipe,
          targetId: widget.item.id,
          apiClient: widget.apiClient,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = BorderRadius.circular(20);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: t.card, borderRadius: radius),
      // Drawn on top so the full-width photo doesn't cover the side borders.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: t.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              item: widget.item,
              auth: widget.auth,
              apiClient: widget.apiClient,
              shoppingListController: widget.shoppingListController,
              onMore: _showMoreSheet,
            ),
            _Photo(item: widget.item, sort: widget.sort),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: t.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _MetaRow(item: widget.item),
                ],
              ),
            ),
            _ActionsRow(
              item: widget.item,
              feed: widget.feed,
              apiClient: widget.apiClient,
              auth: widget.auth,
              onActionCompleted: widget.onActionCompleted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
    required this.onMore,
  });

  final FeedItem item;
  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final VoidCallback onMore;

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          auth: auth,
          apiClient: apiClient,
          shoppingListController: shoppingListController,
          username: item.authorUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final displayName = item.authorDisplayName?.trim().isNotEmpty == true
        ? item.authorDisplayName!.trim()
        : item.authorUsername;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => _openProfile(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Avatar(url: item.authorAvatarUrl, name: displayName),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRelativeTime(context, item.createdAt),
                            style: TextStyle(fontSize: 12.5, color: t.ink2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz_rounded),
            color: t.ink2,
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  /// First letter of [name]. Georgian stays as is: uppercasing it would give
  /// Mtavruli, which isn't how Georgian names are written.
  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "?";
    final first = trimmed.characters.first;
    final code = first.runes.first;
    if (code >= 0x10A0 && code <= 0x10FF) return first;
    return first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final avatarUrl = normalizeAvatarUrl(url);

    return CircleAvatar(
      radius: 20,
      backgroundColor: t.soft,
      foregroundImage: avatarUrl != null
          ? CachedNetworkImageProvider(
              buildImageUrl(avatarUrl),
              cacheKey: avatarUrl,
              maxWidth: 120,
              maxHeight: 120,
            )
          : null,
      // A broken avatar falls back to the initial underneath.
      onForegroundImageError: avatarUrl != null ? (_, _) {} : null,
      child: Text(
        _initial(name),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.brandInk),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.item, required this.sort});

  final FeedItem item;
  final FeedSort sort;

  @override
  Widget build(BuildContext context) {
    final image = item.images.isNotEmpty ? item.images.first : null;

    return AspectRatio(
      aspectRatio: 5 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            RecipeImageWidget(
              imageUrl: image.url,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            )
          else
            const RecipeFallbackImage(
              width: double.infinity,
              height: double.infinity,
              iconSize: 48,
            ),
          // Likes in the window, for the "top" sort
          if (sort == FeedSort.top && item.likesWindow != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      "${item.likesWindow}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cooking time, servings and the recipe's category, each shown only when set.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});

  final FeedItem item;

  /// Label of the first tag that is one of the predefined categories.
  String? _category(AppLocalizations? l) {
    for (final tag in item.tags) {
      final category = findCategory(tag);
      if (category != null) return category.getLabel(l);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final time = formatCookingTime(l, item.cookingTimeMin, item.cookingTimeMax);
    final servings = item.servingSize != null && item.servingSize! > 0 ? item.servingSize : null;
    final category = _category(l);

    if (time == null && servings == null && category == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (time != null) _MetaItem(icon: Icons.schedule_rounded, label: time),
          if (servings != null)
            _MetaItem(
              icon: Icons.person_outline_rounded,
              label: l?.nServings(servings) ?? "$servings servings",
            ),
          if (category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: t.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.brandInk),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: t.ink2),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: t.ink2)),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.item,
    required this.feed,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });

  final FeedItem item;
  final FeedController feed;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        children: [
          _ActionButton(
            icon: item.viewerHasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: item.viewerHasLiked ? _likeRed : t.ink,
            count: item.likes,
            onTap: () async {
              await likeFromFeed(context, feed: feed, recipeId: item.id, auth: auth, apiClient: apiClient);
              onActionCompleted?.call();
            },
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            color: t.ink,
            count: item.comments,
            onTap: () {
              showCommentsBottomSheet(
                context: context,
                recipeId: item.id,
                apiClient: apiClient,
                auth: auth,
                onCommentPosted: () {
                  feed.updateCommentCount(item.id, item.comments + 1);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    onActionCompleted?.call();
                  });
                },
              );
            },
          ),
          const Spacer(),
          // Long-press opens collections (also in the ⋯ menu).
          _ActionButton(
            icon: item.viewerHasBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: t.ink,
            onTap: () async {
              await saveFromFeed(context, feed: feed, recipeId: item.id, auth: auth, apiClient: apiClient);
              onActionCompleted?.call();
            },
            onLongPress: () async {
              final changed = await openCollectionsFromFeed(
                context,
                feed: feed,
                recipeId: item.id,
                auth: auth,
                apiClient: apiClient,
              );
              if (changed) onActionCompleted?.call();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
    this.onLongPress,
  });

  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: color),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                "$count",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _MoreAction { collections, report }

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.showReport});

  final bool showReport;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 10),
          _MoreSheetRow(
            icon: Icons.bookmark_add_outlined,
            label: l?.addToCollection ?? "Add to Collection",
            onTap: () => Navigator.of(context).pop(_MoreAction.collections),
          ),
          if (showReport)
            _MoreSheetRow(
              icon: Icons.flag_outlined,
              label: l?.reportRecipe ?? "Report Recipe",
              onTap: () => Navigator.of(context).pop(_MoreAction.report),
            ),
        ],
      ),
    );
  }
}

class _MoreSheetRow extends StatelessWidget {
  const _MoreSheetRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: t.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
