import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../config.dart";
import "../../localization/app_localizations.dart";
import "../../users/user_api.dart";
import "../../users/user_models.dart";
import "../../utils/ui_utils.dart";

/// Shows a bottom sheet for selecting followers (people who follow you) to share content with
///
/// [alreadySharedWith] - List of user IDs that already have access (will be disabled)
/// [onShare] - Callback when user confirms sharing (userIds, shareType)
/// [showShareTypeSelector] - If true, shows read-only vs collaborative selector
Future<void> showFollowerSelectionBottomSheet({
  required BuildContext context,
  required ApiClient apiClient,
  required AuthController auth,
  List<String> alreadySharedWith = const [],
  required Function(List<String> userIds, String? shareType) onShare,
  bool showShareTypeSelector = false,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FollowerSelectionBottomSheet(
      apiClient: apiClient,
      auth: auth,
      alreadySharedWith: alreadySharedWith,
      onShare: onShare,
      showShareTypeSelector: showShareTypeSelector,
    ),
  );
}

class _FollowerSelectionBottomSheet extends StatefulWidget {
  const _FollowerSelectionBottomSheet({
    required this.apiClient,
    required this.auth,
    required this.alreadySharedWith,
    required this.onShare,
    required this.showShareTypeSelector,
  });

  final ApiClient apiClient;
  final AuthController auth;
  final List<String> alreadySharedWith;
  final Function(List<String> userIds, String? shareType) onShare;
  final bool showShareTypeSelector;

  @override
  State<_FollowerSelectionBottomSheet> createState() => _FollowerSelectionBottomSheetState();
}

class _FollowerSelectionBottomSheetState extends State<_FollowerSelectionBottomSheet> {
  late final UserApi userApi;
  List<UserSearchResult> _followers = [];
  List<UserSearchResult> _filteredFollowers = [];
  bool _isLoading = true;
  String? _error;

  final Set<String> _selectedUserIds = {};
  String _shareType = "read_only"; // For shopping lists
  String _searchQuery = "";
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    userApi = UserApi(widget.apiClient);
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final username = widget.auth.me?["username"]?.toString() ?? "";
      final response = await userApi.getFollowers(username: username, limit: 50);

      setState(() {
        _followers = response.items;
        _filteredFollowers = _followers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterFollowers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFollowers = _followers;
      } else {
        _filteredFollowers = _followers
            .where((user) =>
                user.username.toLowerCase().contains(query.toLowerCase()) ||
                (user.displayName?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _handleShare() async {
    if (_selectedUserIds.isEmpty || _isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      await widget.onShare(
        _selectedUserIds.toList(),
        widget.showShareTypeSelector ? _shareType : null,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Error handling is done in the caller
      setState(() {
        _isSharing = false;
      });
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                  localizations?.selectFollowers ?? "Select followers to share with",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: localizations?.searchFollowers ?? "Search followers",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _filterFollowers,
                ),
              ),

              const SizedBox(height: 16),

              // Share type selector (for shopping lists)
              if (widget.showShareTypeSelector) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations?.shareType ?? "Share type",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: "read_only",
                            label: Text(localizations?.readOnly ?? "Read Only"),
                            icon: const Icon(Icons.visibility),
                          ),
                          ButtonSegment(
                            value: "collaborative",
                            label: Text(localizations?.collaborative ?? "Collaborative"),
                            icon: const Icon(Icons.edit),
                          ),
                        ],
                        selected: {_shareType},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            _shareType = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shareType == "read_only"
                            ? (localizations?.readOnlyDescription ?? "Others can view but not edit")
                            : (localizations?.collaborativeDescription ?? "Others can check/uncheck items"),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Followers list
              Expanded(
                child: _buildFollowersList(scrollController, localizations, theme),
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _selectedUserIds.isEmpty || _isSharing ? null : _handleShare,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isSharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _selectedUserIds.isEmpty
                                ? (localizations?.selectFollowers ?? "Select followers")
                                : localizations?.shareWithNPeople(_selectedUserIds.length) ?? "Share with ${_selectedUserIds.length} ${_selectedUserIds.length == 1 ? "person" : "people"}",
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFollowersList(
    ScrollController scrollController,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.error ?? "Error",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_filteredFollowers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? (localizations?.noFollowersToShareWith ?? "No followers to share with")
                  : "No followers found",
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _filteredFollowers.length,
      itemBuilder: (context, index) {
        final user = _filteredFollowers[index];
        final isAlreadyShared = widget.alreadySharedWith.contains(user.userId);
        final isSelected = _selectedUserIds.contains(user.userId);

        return CheckboxListTile(
          value: isAlreadyShared || isSelected,
          onChanged: isAlreadyShared ? null : (_) => _toggleSelection(user.userId),
          enabled: !isAlreadyShared,
          secondary: buildUserAvatar(
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
              if (isAlreadyShared) ...[
                const SizedBox(height: 4),
                Text(
                  localizations?.alreadyShared ?? "Already shared",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
