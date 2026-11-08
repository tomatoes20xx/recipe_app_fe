import "package:flutter/material.dart";

import "../../feed/feed_models.dart";
import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "../../utils/paginated_list_controller.dart";
import "../empty_state_widget.dart";
import "recipe_grid_tile.dart";

/// A recipe list as a 2-column grid with infinite scroll, pull to refresh and
/// loading / error / empty states. Loads [controller] the first time it is
/// shown. Used by the Recipes and Liked recipes screens.
class PaginatedRecipeGrid extends StatefulWidget {
  const PaginatedRecipeGrid({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDescription,
    this.onRefresh,
  });

  final PaginatedListController<FeedItem> controller;
  final ValueChanged<FeedItem> onOpen;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;

  /// Extra work for pull to refresh, run alongside reloading the list.
  final Future<void> Function()? onRefresh;

  @override
  State<PaginatedRecipeGrid> createState() => _PaginatedRecipeGridState();
}

class _PaginatedRecipeGridState extends State<PaginatedRecipeGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    if (widget.controller.items.isEmpty && !widget.controller.isLoading) {
      widget.controller.loadInitial();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Same trigger as ProfileScreen's grid: load more within 300px of the end.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 300) return;
    widget.controller.loadMore();
  }

  /// Empty, error and loading states still need to scroll for pull to refresh.
  Widget _fill(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight, child: child)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final controller = widget.controller;
    final items = controller.items;

    final Widget body;
    if (controller.isLoading && items.isEmpty) {
      body = _fill(Center(child: CircularProgressIndicator(color: t.brandInk)));
    } else if (controller.error != null && items.isEmpty) {
      body = _fill(Center(
        child: TextButton(
          onPressed: controller.loadInitial,
          style: TextButton.styleFrom(foregroundColor: t.brandInk),
          child: Text(l?.retry ?? "Retry"),
        ),
      ));
    } else if (items.isEmpty) {
      body = _fill(Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStateWidget(
          icon: widget.emptyIcon,
          title: widget.emptyTitle,
          description: widget.emptyDescription,
        ),
      ));
    } else {
      final rows = (items.length + 1) ~/ 2;
      body = ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: rows + (controller.isLoadingMore ? 1 : 0),
        itemBuilder: (context, row) {
          if (row >= rows) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: t.brandInk)),
            );
          }
          final i = row * 2;
          return Padding(
            padding: EdgeInsets.only(bottom: row < rows - 1 ? 16 : 0),
            child: RecipeGridRow(
              left: items[i],
              right: i + 1 < items.length ? items[i + 1] : null,
              onTap: widget.onOpen,
            ),
          );
        },
      );
    }

    final extraRefresh = widget.onRefresh;
    return RefreshIndicator(
      color: t.brandInk,
      onRefresh: () => Future.wait([
        controller.refresh(),
        if (extraRefresh != null) extraRefresh(),
      ]),
      child: body,
    );
  }
}
