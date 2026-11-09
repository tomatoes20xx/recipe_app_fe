import "package:flutter/material.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";

/// Follow / Following in a user row. Same look as the profile's follow
/// button, at chip height: the primary button to follow, an outlined `card`
/// button once following.
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
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    const size = Size(0, 36);
    const padding = EdgeInsets.symmetric(horizontal: 16);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    final label = Text(isFollowing ? (l?.followingUser ?? "Following") : (l?.follow ?? "Follow"));
    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: t.brandInk),
    );

    if (isFollowing) {
      return OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: padding,
          shape: shape,
          backgroundColor: t.card,
          foregroundColor: t.ink,
          side: BorderSide(color: t.line),
          textStyle: textStyle,
        ),
        child: isLoading ? spinner : label,
      );
    }
    return FilledButton(
      onPressed: isLoading ? null : onTap,
      style: FilledButton.styleFrom(minimumSize: size, padding: padding, shape: shape, textStyle: textStyle),
      child: isLoading ? spinner : label,
    );
  }
}
