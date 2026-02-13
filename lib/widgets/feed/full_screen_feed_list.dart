import "package:flutter/material.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../feed/feed_controller.dart";
import "../../localization/app_localizations.dart";
import "../../shopping/shopping_list_controller.dart";
import "../empty_state_widget.dart";
import "../native_ad_card_widget.dart";
import "full_screen_feed_card.dart";

/// Full-screen feed list widget (vertical page view like TikTok)
class FullScreenFeedList extends StatefulWidget {
  const FullScreenFeedList({
    super.key,
    required this.feed,
    required this.pageController,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
    this.onPageChanged,
    this.onActionCompleted,
  });

  final FeedController feed;
  final PageController pageController;
  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onActionCompleted;

  @override
  State<FullScreenFeedList> createState() => _FullScreenFeedListState();
}

class _FullScreenFeedListState extends State<FullScreenFeedList> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    final newPage = widget.pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      widget.onPageChanged?.call(newPage);
      // Load more when near the end
      if (newPage >= widget.feed.items.length - 2 && widget.feed.nextCursor != null) {
        widget.feed.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feed.isLoading && widget.feed.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.feed.error != null && widget.feed.items.isEmpty) {
      return ErrorStateWidget(
        message: widget.feed.error!,
        onRetry: widget.feed.loadInitial,
      );
    }

    // Calculate total items including ads (show ad every 5 items, starting after 3rd item)
    final adInterval = 5;
    final adStartIndex = 3;
    int getAdCount(int totalItems) {
      if (totalItems < adStartIndex) return 0;
      return ((totalItems - adStartIndex) / adInterval).floor() + 1;
    }

    final totalAdCount = getAdCount(widget.feed.items.length);
    final totalItemCount =
        widget.feed.items.length + totalAdCount + (widget.feed.nextCursor != null ? 1 : 0);

    bool isAdIndex(int index) {
      if (index < adStartIndex) return false;
      final adjustedIndex = index - adStartIndex;
      return adjustedIndex % (adInterval + 1) == 0;
    }

    int getRecipeIndex(int displayIndex) {
      int recipeIndex = 0;
      for (int i = 0; i < displayIndex; i++) {
        if (!isAdIndex(i)) {
          recipeIndex++;
        }
      }
      return recipeIndex;
    }

    return PageView.builder(
      controller: widget.pageController,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      itemCount: totalItemCount,
      allowImplicitScrolling: false, // Disable pre-rendering for better performance
      onPageChanged: (index) {
        widget.onPageChanged?.call(index);
      },
      itemBuilder: (context, index) {
        // Loading indicator at the end
        if (index >= widget.feed.items.length + totalAdCount) {
          if (widget.feed.isLoadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          return Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Center(child: Text(localizations?.noMoreItems ?? "No more items"));
            },
          );
        }

        // Check if this index should show an ad
        if (isAdIndex(index)) {
          return NativeAdFullScreenWidget(adIndex: index);
        }

        // Get the actual recipe index
        final recipeIndex = getRecipeIndex(index);
        if (recipeIndex >= widget.feed.items.length) {
          return const SizedBox.shrink();
        }

        final item = widget.feed.items[recipeIndex];
        // RepaintBoundary prevents repaints from propagating to/from this widget,
        // improving performance for complex full-screen cards with images
        return RepaintBoundary(
          child: FullScreenFeedCard(
            item: item,
            sort: widget.feed.sort,
            feed: widget.feed,
            apiClient: widget.apiClient,
            auth: widget.auth,
            shoppingListController: widget.shoppingListController,
            onActionCompleted: widget.onActionCompleted,
          ),
        );
      },
    );
  }
}
