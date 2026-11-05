import "package:flutter/material.dart";

import "../../api/api_client.dart";
import "../../auth/auth_controller.dart";
import "../../auth/require_account.dart";
import "../../collections/add_to_collection_bottom_sheet.dart";
import "../../feed/feed_controller.dart";
import "../../services/push_prompt_service.dart";

// Like / save / collections from a feed card (list and full-screen cards share
// these). Guests are asked for an account first; a card that was showing the
// guest's flags then simply likes or saves, which is what they tapped for.

Future<void> likeFromFeed(
  BuildContext context, {
  required FeedController feed,
  required String recipeId,
  required AuthController auth,
  required ApiClient apiClient,
}) async {
  if (!await requireAccount(context, auth, AccountReason.like)) return;
  final i = feed.items.indexWhere((x) => x.id == recipeId);
  if (i < 0) return;
  final wasLiked = feed.items[i].viewerHasLiked;
  final error = await feed.toggleLike(recipeId);
  if (!context.mounted) return;
  if (error != null) {
    await handleAuthError(context, auth, error, AccountReason.like);
  } else if (!wasLiked) {
    PushPromptService().onLikeCompleted(context, apiClient);
  }
}

Future<void> saveFromFeed(
  BuildContext context, {
  required FeedController feed,
  required String recipeId,
  required AuthController auth,
  required ApiClient apiClient,
}) async {
  if (!await requireAccount(context, auth, AccountReason.save)) return;
  final i = feed.items.indexWhere((x) => x.id == recipeId);
  if (i < 0) return;
  final wasSaved = feed.items[i].viewerHasBookmarked;
  final error = await feed.toggleBookmark(recipeId);
  if (!context.mounted) return;
  if (error != null) {
    await handleAuthError(context, auth, error, AccountReason.save);
  } else if (!wasSaved) {
    PushPromptService().onSaveCompleted(context, apiClient);
  }
}

/// Long-press on the save button. Returns true when collections changed.
Future<bool> openCollectionsFromFeed(
  BuildContext context, {
  required FeedController feed,
  required String recipeId,
  required AuthController auth,
  required ApiClient apiClient,
}) async {
  if (!await requireAccount(context, auth, AccountReason.collections)) return false;
  if (!context.mounted) return false;
  final result = await showAddToCollectionBottomSheet(
    context: context,
    apiClient: apiClient,
    recipeId: recipeId,
  );
  if (!result.changed) return false;
  feed.updateBookmarkState(recipeId, result.isBookmarked);
  return true;
}
