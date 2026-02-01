import "package:flutter/material.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../feed/feed_controller.dart";
import "../../localization/app_localizations.dart";
import "../../recipes/recipe_detail_screen.dart";
import "../empty_state_widget.dart";
import "../native_ad_card_widget.dart";
import "feed_card.dart";
import "feed_card_skeleton.dart";

/// Feed list widget (scrollable list view)
class FeedList extends StatelessWidget {
  const FeedList({
    super.key,
    required this.feed,
    required this.controller,
    required this.apiClient,
    required this.auth,
    this.onActionCompleted,
  });

  final FeedController feed;
  final ScrollController controller;
  final ApiClient apiClient;
  final AuthController auth;
  final VoidCallback? onActionCompleted;

  @override
  Widget build(BuildContext context) {
    if (feed.isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: 5, // Show 5 skeleton cards
        itemBuilder: (context, i) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: i == 0 ? 16 : 8,
            ),
            child: const FeedCardSkeleton(),
          );
        },
      );
    }

    if (feed.error != null && feed.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const SizedBox(height: 120),
          ErrorStateWidget(
            message: feed.error!,
            onRetry: feed.loadInitial,
          ),
        ],
      );
    }

    // Calculate total items including ads (show ad every 5 items, starting after 3rd item)
    final adInterval = 5;
    final adStartIndex = 3;
    int getAdCount(int totalItems) {
      if (totalItems < adStartIndex) return 0;
      return ((totalItems - adStartIndex) / adInterval).floor() + 1;
    }

    final totalAdCount = getAdCount(feed.items.length);
    final totalItemCount = feed.items.length + totalAdCount + 1; // + footer

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

    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      cacheExtent: 100, // Further reduced to minimize simultaneous ad loading
      itemCount: totalItemCount,
      itemBuilder: (context, i) {
        // Footer
        if (i >= feed.items.length + totalAdCount) {
          if (feed.isLoadingMore) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }
          if (feed.nextCursor == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Center(
                    child: Text(
                      localizations?.noMoreItems ?? "No more items",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                  );
                },
              ),
            );
          }
          return const SizedBox(height: 60);
        }

        // Check if this index should show an ad
        if (isAdIndex(i)) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: i == 0 ? 16 : 8,
              bottom: 8,
            ),
            child: NativeAdCardWidget(adIndex: i),
          );
        }

        // Get the actual recipe index
        final recipeIndex = getRecipeIndex(i);
        if (recipeIndex >= feed.items.length) {
          return const SizedBox.shrink();
        }

        final item = feed.items[recipeIndex];
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: i == 0 ? 16 : 8,
            bottom: i == totalItemCount - 2 ? 0 : 0,
          ),
          // RepaintBoundary prevents repaints from propagating to/from this widget,
          // improving scroll performance for complex cards with images
          child: RepaintBoundary(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipeId: item.id,
                        apiClient: apiClient,
                        auth: auth,
                      ),
                    ),
                  );
                  // If result contains updated comment count, update the feed item
                  if (result != null && result is int) {
                    feed.updateCommentCount(item.id, result);
                  }
                },
                child: FeedCard(
                  item: item,
                  sort: feed.sort,
                  feed: feed,
                  apiClient: apiClient,
                  auth: auth,
                  onActionCompleted: onActionCompleted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
