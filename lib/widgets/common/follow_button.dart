import "package:flutter/material.dart";

/// Reusable follow/following button widget.
/// Displays different styles based on follow state.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.isFollowing,
    required this.onTap,
    this.isLoading = false,
  });

  final bool isFollowing;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: isLoading ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: isFollowing
              ? theme.colorScheme.outline
              : theme.colorScheme.primary,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFollowing
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.primary,
                ),
              ),
            )
          : Text(
              isFollowing ? "Following" : "Follow",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isFollowing
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.primary,
              ),
            ),
    );
  }
}
