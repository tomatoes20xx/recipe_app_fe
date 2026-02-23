import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";
import "collection_api.dart";
import "collection_models.dart";

/// Shows the add-to-collection bottom sheet.
/// Returns `true` if the recipe's bookmark state changed.
Future<bool> showAddToCollectionBottomSheet({
  required BuildContext context,
  required ApiClient apiClient,
  required String recipeId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddToCollectionSheet(
      apiClient: apiClient,
      recipeId: recipeId,
    ),
  );
  return result ?? false;
}

/// Sentinel value meaning "regular bookmarks (no collection)".
const _regularBookmarks = "__regular__";

class _AddToCollectionSheet extends StatefulWidget {
  const _AddToCollectionSheet({
    required this.apiClient,
    required this.recipeId,
  });

  final ApiClient apiClient;
  final String recipeId;

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  late final CollectionApi _api;
  List<Collection> _collections = [];
  /// null = regular bookmark or not bookmarked, collection ID = in that collection
  String? _currentCollectionId;
  bool _isBookmarked = false;
  bool _isLoading = true;
  String? _error;
  String? _processingId;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _api = CollectionApi(widget.apiClient);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getCollections(),
        _api.getRecipeCollection(widget.recipeId),
      ]);

      final collectionsRes = results[0] as CollectionsResponse;
      final currentCollection = results[1] as RecipeCollectionInfo?;

      if (mounted) {
        setState(() {
          _collections = collectionsRes.items;
          _currentCollectionId = currentCollection?.collectionId;
          // If in a collection or this sheet was opened (bookmark long-press),
          // the recipe is bookmarked
          _isBookmarked = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectCollection(String collectionId) async {
    if (_processingId != null) return;
    if (collectionId == _currentCollectionId) return;

    setState(() => _processingId = collectionId);

    try {
      await _api.addRecipe(collectionId, widget.recipeId);
      if (mounted) {
        _didChange = true;
        setState(() {
          _currentCollectionId = collectionId;
          _isBookmarked = true;
          _processingId = null;
        });
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          localizations?.recipeAddedToCollection ?? "Added to collection",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingId = null);
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _moveToRegularBookmarks() async {
    if (_processingId != null) return;
    if (_currentCollectionId == null) return; // already regular

    setState(() => _processingId = _regularBookmarks);

    try {
      await _api.moveToBookmarks(_currentCollectionId!, widget.recipeId);
      if (mounted) {
        _didChange = true;
        setState(() {
          _currentCollectionId = null;
          _processingId = null;
        });
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          localizations?.movedToBookmarks ?? "Moved to bookmarks",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingId = null);
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _removeBookmark() async {
    if (_processingId != null) return;

    final localizations = AppLocalizations.of(context);

    // If in a collection, we need the collection ID for the DELETE call
    if (_currentCollectionId != null) {
      setState(() => _processingId = "__remove__");
      try {
        await _api.removeRecipe(_currentCollectionId!, widget.recipeId);
        if (mounted) {
          _didChange = true;
          setState(() {
            _isBookmarked = false;
            _currentCollectionId = null;
            _processingId = null;
          });
          ErrorUtils.showSuccess(
            context,
            localizations?.bookmarkRemoved ?? "Removed from saved recipes",
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _processingId = null);
          ErrorUtils.showError(context, e);
        }
      }
    } else {
      // Regular bookmark — just close and let the caller handle unbookmark
      // via the normal bookmark toggle
      _didChange = true;
      if (mounted) Navigator.of(context).pop(_didChange);
    }
  }

  Future<void> _createNewCollection() async {
    final localizations = AppLocalizations.of(context);
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations?.createCollection ?? "Create Collection"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: localizations?.enterCollectionName ??
                "Enter collection name",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: Text(localizations?.create ?? "Create"),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      try {
        final collection = await _api.createCollection(name);
        await _api.addRecipe(collection.id, widget.recipeId);
        if (mounted) {
          _didChange = true;
          setState(() {
            _collections.insert(0, collection);
            _currentCollectionId = collection.id;
            _isBookmarked = true;
          });
          ErrorUtils.showSuccess(
            context,
            localizations?.collectionCreated ?? "Collection created",
          );
        }
      } catch (e) {
        if (mounted) ErrorUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isInCollection = _currentCollectionId != null;
    final isRegularBookmark = _isBookmarked && !isInCollection;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_didChange);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    localizations?.addToCollection ?? "Add to Collection",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text(_error!,
                        style:
                            TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: _loadData,
                        child: const Text("Retry")),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    // Regular Bookmarks option
                    _buildRegularBookmarksItem(
                        theme, localizations, isRegularBookmark),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    // Create new collection
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        localizations?.createNew ?? "Create new",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _createNewCollection,
                    ),
                    // Existing collections
                    ..._collections.map((collection) =>
                        _buildCollectionItem(
                            theme, localizations, collection)),
                    // Remove bookmark option (at the bottom)
                    if (_isBookmarked) ...[
                      const Divider(
                          height: 1, indent: 16, endIndent: 16),
                      _buildRemoveBookmarkItem(theme, localizations),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularBookmarksItem(
      ThemeData theme, AppLocalizations? localizations, bool isSelected) {
    final isProcessing = _processingId == _regularBookmarks;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isSelected ? Icons.bookmark : Icons.bookmark_border,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 20,
        ),
      ),
      title: Text(
        localizations?.regularBookmarks ?? "Regular Bookmarks",
        style: isSelected
            ? TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      trailing: isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isSelected
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : Icon(Icons.circle_outlined,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: _currentCollectionId != null ? _moveToRegularBookmarks : null,
    );
  }

  Widget _buildCollectionItem(ThemeData theme,
      AppLocalizations? localizations, Collection collection) {
    final isSelected = _currentCollectionId == collection.id;
    final isProcessing = _processingId == collection.id;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isSelected
              ? Icons.collections_bookmark
              : Icons.collections_bookmark_outlined,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 20,
        ),
      ),
      title: Text(
        collection.name,
        style: isSelected
            ? TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      subtitle: Text(
        localizations?.nRecipes(collection.recipeCount) ??
            "${collection.recipeCount} recipes",
        style: theme.textTheme.bodySmall,
      ),
      trailing: isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isSelected
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : Icon(Icons.circle_outlined,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: () => _selectCollection(collection.id),
    );
  }

  Widget _buildRemoveBookmarkItem(
      ThemeData theme, AppLocalizations? localizations) {
    final isProcessing = _processingId == "__remove__";

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.bookmark_remove_outlined,
          color: theme.colorScheme.error,
          size: 20,
        ),
      ),
      title: Text(
        localizations?.removeBookmark ?? "Remove Bookmark",
        style: TextStyle(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _removeBookmark,
    );
  }
}
