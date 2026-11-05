import "package:flutter/material.dart";

import "../../auth/account_reason.dart";
import "../../localization/app_localizations.dart";

/// What the user picked in the account prompt sheet.
enum AuthPromptChoice { google, emailSignUp, logIn }

/// Bottom sheet shown when a guest taps something that needs an account.
/// Returns the chosen sign-in method, or null for "Not now" / dismiss.
Future<AuthPromptChoice?> showAuthPromptSheet(
  BuildContext context, {
  required AccountReason reason,
  required bool needsVerification,
}) {
  return showModalBottomSheet<AuthPromptChoice>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AuthPromptSheet(reason: reason, needsVerification: needsVerification),
  );
}

class _AuthPromptSheet extends StatelessWidget {
  const _AuthPromptSheet({required this.reason, required this.needsVerification});

  final AccountReason reason;
  final bool needsVerification;

  String _title(AppLocalizations? l) {
    switch (reason) {
      case AccountReason.save:
        return l?.authPromptTitleSave ?? "Create an account to save recipes";
      case AccountReason.like:
        return l?.authPromptTitleLike ?? "Create an account to like recipes";
      case AccountReason.cook:
        return l?.authPromptTitleCook ?? "Create an account to track what you cook";
      case AccountReason.collections:
        return l?.authPromptTitleCollections ?? "Create an account to organize collections";
      case AccountReason.shoppingList:
        return l?.authPromptTitleShoppingList ?? "Create an account to use the shopping list";
      case AccountReason.share:
        return l?.authPromptTitleShare ?? "Create an account to share recipes";
      case AccountReason.report:
        return l?.authPromptTitleReport ?? "Create an account to report content";
      case AccountReason.block:
        return l?.authPromptTitleBlock ?? "Create an account to block users";
      case AccountReason.notifications:
        return l?.authPromptTitleNotifications ?? "Create an account to get notifications";
      case AccountReason.following:
        return l?.authPromptTitleFollowing ?? "Create an account to see recipes from people you follow";
      case AccountReason.comment:
        return l?.authPromptTitleComment ?? "Create an account to comment";
      case AccountReason.follow:
        return l?.authPromptTitleFollow ?? "Create an account to follow cooks";
      case AccountReason.create:
        return l?.authPromptTitleCreate ?? "Create an account to share your recipes";
      case AccountReason.sessionExpired:
        return l?.welcomeBackTitle ?? "Welcome back!";
      case AccountReason.account:
        return l?.authPromptTitleGeneric ?? "Sign up or log in";
    }
  }

  IconData get _icon {
    switch (reason) {
      case AccountReason.save:
      case AccountReason.collections:
        return Icons.bookmark_outline;
      case AccountReason.like:
        return Icons.favorite_outline;
      case AccountReason.cook:
        return Icons.restaurant_outlined;
      case AccountReason.shoppingList:
        return Icons.shopping_cart_outlined;
      case AccountReason.share:
        return Icons.send_outlined;
      case AccountReason.report:
        return Icons.flag_outlined;
      case AccountReason.block:
        return Icons.block_outlined;
      case AccountReason.notifications:
        return Icons.notifications_outlined;
      case AccountReason.following:
      case AccountReason.follow:
        return Icons.people_outline;
      case AccountReason.comment:
        return Icons.chat_bubble_outline;
      case AccountReason.create:
        return Icons.add_circle_outline;
      case AccountReason.sessionExpired:
      case AccountReason.account:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final isWelcomeBack = reason == AccountReason.sessionExpired;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(_icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              _title(l),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isWelcomeBack
                  ? (l?.welcomeBackBody ?? "Your session ended. Log in again to see your saved recipes.")
                  : (l?.authPromptBody ?? "It's free and takes a few seconds."),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted),
            ),
            if (needsVerification) ...[
              const SizedBox(height: 4),
              Text(
                l?.authPromptVerifyNote ?? "We'll email you a 6-digit code to confirm your address.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(AuthPromptChoice.google),
                icon: Image.asset(
                  "assets/images/android_light_rd_na.png",
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 18),
                ),
                label: Text(l?.continueWithGoogle ?? "Continue with Google"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!isWelcomeBack) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(AuthPromptChoice.emailSignUp),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(l?.authPromptSignUpEmail ?? "Sign up with email"),
                ),
              ),
              const SizedBox(height: 4),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(AuthPromptChoice.logIn),
              child: Text(
                isWelcomeBack
                    ? (l?.login ?? "Log in")
                    : (l?.authPromptLogIn ?? "I already have an account"),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l?.notNow ?? "Not now", style: TextStyle(color: muted)),
            ),
          ],
        ),
      ),
    );
  }
}
