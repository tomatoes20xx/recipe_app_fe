import "package:flutter/material.dart";
import "../localization/app_localizations.dart";
import "../utils/ui_utils.dart";
import "recipe_detail_models.dart";

Future<void> showLikedByBottomSheet({
  required BuildContext context,
  required List<LikedByUser> likedBy,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return _LikedByBottomSheet(
          likedBy: likedBy,
          scrollController: scrollController,
        );
      },
    ),
  );
}

class _LikedByBottomSheet extends StatelessWidget {
  const _LikedByBottomSheet({
    required this.likedBy,
    required this.scrollController,
  });

  final List<LikedByUser> likedBy;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "${localizations?.likedBy ?? "Liked by"} (${likedBy.length})",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),

          // User list
          Expanded(
            child: likedBy.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        localizations?.noLikesYet ?? "No likes yet",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: likedBy.length,
                    itemBuilder: (context, index) {
                      final user = likedBy[index];
                      return _UserTile(user: user);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final LikedByUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: buildUserAvatar(
        context,
        user.avatarUrl,
        user.username,
        radius: 20,
      ),
      title: Text(
        user.displayName ?? user.username,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: user.displayName != null
          ? Text(
              "@${user.username}",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : null,
      trailing: Text(
        formatRelativeTime(context, user.likedAt),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
