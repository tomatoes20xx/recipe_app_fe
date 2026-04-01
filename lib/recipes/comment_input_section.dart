import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../localization/app_localizations.dart';
import '../utils/ui_utils.dart';

class CommentInputSection extends StatelessWidget {
  const CommentInputSection({
    super.key,
    required this.auth,
    required this.commentController,
    required this.focusNode,
    required this.replyingToId,
    required this.replyingToUsername,
    required this.isSubmitting,
    required this.hasText,
    required this.onSubmit,
    required this.onCancelReply,
  });

  final AuthController? auth;
  final TextEditingController commentController;
  final FocusNode focusNode;
  final String? replyingToId;
  final String? replyingToUsername;
  final bool isSubmitting;
  final bool hasText;
  final VoidCallback onSubmit;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoggedIn = auth?.isLoggedIn ?? false;
    final isBanned = auth?.isSoftBanned == true || auth?.isPermanentlyBanned == true;

    if (isBanned) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.block_rounded, size: 20, color: colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    auth?.isPermanentlyBanned == true
                        ? (localizations?.accountPermanentlyBanned ?? "Account Permanently Suspended")
                        : auth?.softBannedUntil != null
                            ? localizations?.accountSoftBannedUntil(
                                  formatDate(context, auth!.softBannedUntil!),
                                ) ??
                                "Account Temporarily Suspended"
                            : (localizations?.cannotCommentWhileBanned ?? "You cannot comment while your account is suspended"),
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (!isLoggedIn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              localizations?.logInToComment ?? "Log in to comment",
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final userAvatar = auth?.me?["avatar_url"]?.toString();
    final username = auth?.me?["username"]?.toString() ?? "";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: colorScheme.surface),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reply indicator
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: replyingToId != null && replyingToUsername != null
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.reply_rounded, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    children: [
                                      TextSpan(text: localizations?.replyingTo ?? "Replying to "),
                                      TextSpan(
                                        text: "@$replyingToUsername",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: onCancelReply,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Input row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: buildUserAvatar(context, userAvatar, username, radius: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        focusNode: focusNode,
                        maxLines: 4,
                        minLines: 1,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        style: textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: replyingToId != null
                              ? (localizations?.writeAReply ?? "Write a reply...")
                              : (localizations?.shareYourThoughts ?? "Share your thoughts..."),
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          counterText: "",
                          filled: true,
                          fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Animated send button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                key: const ValueKey("loading"),
                                width: 40,
                                height: 40,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )
                            : hasText
                                ? IconButton(
                                    key: const ValueKey("send"),
                                    onPressed: onSubmit,
                                    icon: Icon(
                                      Icons.send_rounded,
                                      color: colorScheme.primary,
                                      size: 22,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                      shape: const CircleBorder(),
                                      fixedSize: const Size(40, 40),
                                    ),
                                    tooltip: localizations?.postComment ?? "Post comment",
                                  )
                                : const SizedBox(key: ValueKey("empty"), width: 40, height: 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
