import "package:flutter/material.dart";

import "../../localization/app_localizations.dart";
import "../../sharing/sharing_models.dart";
import "../../utils/ui_utils.dart";

/// Shows a bottom sheet displaying who has access to shared content
///
/// [sharedWith] - List of users who have access
/// [onUnshare] - Callback when user removes access (userId)
/// [isLoading] - Whether data is loading
Future<void> showSharedWithBottomSheet({
  required BuildContext context,
  required List<SharedWithUser> sharedWith,
  required Function(String userId) onUnshare,
  bool isLoading = false,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SharedWithBottomSheet(
      sharedWith: sharedWith,
      onUnshare: onUnshare,
      isLoading: isLoading,
    ),
  );
}

class _SharedWithBottomSheet extends StatefulWidget {
  const _SharedWithBottomSheet({
    required this.sharedWith,
    required this.onUnshare,
    required this.isLoading,
  });

  final List<SharedWithUser> sharedWith;
  final Function(String userId) onUnshare;
  final bool isLoading;

  @override
  State<_SharedWithBottomSheet> createState() => _SharedWithBottomSheetState();
}

class _SharedWithBottomSheetState extends State<_SharedWithBottomSheet> {
  final Set<String> _unsharingUserIds = {};

  Future<void> _confirmAndUnshare(SharedWithUser user) async {
    final localizations = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeAccess ?? "Remove Access"),
        content: Text(
          localizations?.removeAccessConfirm ?? "Are you sure you want to remove access for @${user.username}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations?.removeAccess ?? "Remove Access"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _unsharingUserIds.add(user.userId);
      });

      try {
        await widget.onUnshare(user.userId);
      } catch (e) {
        // Error is handled by caller
      } finally {
        if (mounted) {
          setState(() {
            _unsharingUserIds.remove(user.userId);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.sharedWith.isEmpty
                      ? (localizations?.sharedWith ?? "Shared with")
                      : "${localizations?.sharedWith ?? "Shared with"} ${widget.sharedWith.length} ${widget.sharedWith.length == 1 ? "person" : "people"}",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Content
              Expanded(
                child: _buildContent(scrollController, localizations, theme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    ScrollController scrollController,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (widget.sharedWith.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.notSharedWithAnyone ?? "Not shared with anyone",
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: widget.sharedWith.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final user = widget.sharedWith[index];
        final isUnsharing = _unsharingUserIds.contains(user.userId);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: buildUserAvatar(
              context,
              user.avatarUrl,
              user.username,
              radius: 20,
            ),
            title: Text(
              user.displayName ?? user.username,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@${user.username}"),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (user.shareType != null) ...[
                      _ShareTypeBadge(shareType: user.shareType!),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      formatRelativeTime(context, user.sharedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: isUnsharing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.person_remove),
                    onPressed: () => _confirmAndUnshare(user),
                    tooltip: localizations?.unshare ?? "Unshare",
                    color: theme.colorScheme.error,
                  ),
          ),
        );
      },
    );
  }
}

class _ShareTypeBadge extends StatelessWidget {
  const _ShareTypeBadge({required this.shareType});

  final String shareType;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final isReadOnly = shareType == "read_only";
    final label = isReadOnly
        ? (localizations?.readOnly ?? "Read Only")
        : (localizations?.collaborative ?? "Collaborative");
    final icon = isReadOnly ? Icons.visibility : Icons.edit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReadOnly
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isReadOnly
                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isReadOnly
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
