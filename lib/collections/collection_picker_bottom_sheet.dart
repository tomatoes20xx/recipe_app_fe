import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";
import "../widgets/common/app_bottom_sheet.dart";
import "collection_api.dart";
import "collection_models.dart";

/// Shows a bottom sheet to pick a collection destination.
/// Returns the selected [Collection], or null if dismissed.
Future<Collection?> showCollectionPickerBottomSheet({
  required BuildContext context,
  required ApiClient apiClient,
}) async {
  return showAppBottomSheet<Collection>(
    context: context,
    builder: (context) => _CollectionPickerSheet(apiClient: apiClient),
  );
}

class _CollectionPickerSheet extends StatefulWidget {
  const _CollectionPickerSheet({required this.apiClient});

  final ApiClient apiClient;

  @override
  State<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<_CollectionPickerSheet> {
  late final CollectionApi _api;
  List<Collection> _collections = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = CollectionApi(widget.apiClient);
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _api.getCollections();
      if (mounted) {
        setState(() {
          _collections = res.items;
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
        if (mounted) {
          Navigator.of(context).pop(collection);
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: SafeArea(
        top: false,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    localizations?.moveToCollection ?? "Move to Collection",
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
                        style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: _loadCollections,
                        child: Text(localizations?.retry ?? "Retry")),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
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
                    ..._collections.map((collection) => ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.collections_bookmark_outlined,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ),
                          title: Text(collection.name),
                          subtitle: Text(
                            localizations?.nRecipes(collection.recipeCount) ??
                                "${collection.recipeCount} recipes",
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => Navigator.of(context).pop(collection),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
