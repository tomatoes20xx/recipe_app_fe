import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";
import "profile_avatar.dart";

/// A user in a list (search results, followers, following): 44px avatar,
/// name and @handle, an optional [trailing] (usually a FollowButton), on a
/// `card` row with a 1px `line` border, radius 16. [framed] false drops the
/// card for rows inside a sheet.
class UserListTile extends StatelessWidget {
  const UserListTile({
    super.key,
    required this.username,
    required this.onTap,
    this.displayName,
    this.avatarUrl,
    this.trailing,
    this.framed = true,
  });

  final String username;
  final String? displayName;
  final String? avatarUrl;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final name = displayName?.trim().isNotEmpty == true ? displayName!.trim() : username;
    final radius = BorderRadius.circular(16);

    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: framed ? 12 : 16, vertical: 10),
      child: Row(
        children: [
          ProfileAvatar(avatarUrl: avatarUrl, name: name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  "@$username",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.ink2),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    if (!framed) return InkWell(onTap: onTap, child: row);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: t.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
