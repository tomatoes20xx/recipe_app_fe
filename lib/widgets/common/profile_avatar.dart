import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";
import "../../utils/ui_utils.dart";

/// Round avatar used by the bottom nav and the Profile tab: the user's photo,
/// or their initial on `soft` with `brandInk` text when there is none.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.size,
  });

  final String? avatarUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final url = avatarUrl;
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : "",
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: t.brandInk,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          height: 1.0,
        ),
      ),
    );
    if (url == null || url.isEmpty || url == "null") return initial;

    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: buildImageUrl(url),
        cacheKey: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: px,
        memCacheHeight: px,
        placeholder: (_, _) => initial,
        errorWidget: (_, _, _) => initial,
      ),
    );
  }
}
