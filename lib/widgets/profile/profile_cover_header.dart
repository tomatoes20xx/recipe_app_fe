import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart" show OverScrollHeaderStretchConfiguration;
import "package:flutter/services.dart";

import "../../theme/app_tokens.dart";
import "../../theme/status_bar.dart";
import "../../utils/ui_utils.dart";
import "../common/profile_avatar.dart";

/// The cover header shared by the Profile tab and other users' profiles
/// (docs/profile-cover.md): the cover photo with scrims, round buttons on it,
/// the avatar with name and handle at its bottom, and a `bg` toolbar it
/// collapses into while scrolling.

/// Avatar on the cover, its 3px white border included.
const double profileCoverAvatarSize = 76;

/// The identity row sits this far above the cover's bottom edge.
const double _identityBottom = 18;

/// Cover without a photo, in light and dark (white text on it is ~7:1).
const Color profileNoCoverColor = Color(0xFF2C5E40);

/// The collapsed header's toolbar height (status bar not included).
const double profileCoverToolbarHeight = 56;

/// Pins [builder]'s header between [minExtent] and [maxExtent] and reports
/// how far it has collapsed (0 = expanded, 1 = down to the toolbar).
class ProfileCoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  ProfileCoverHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final Widget Function(BuildContext context, double collapse) builder;

  /// iOS overscroll stretches the cover instead of opening a gap above it.
  @override
  final OverScrollHeaderStretchConfiguration stretchConfiguration =
      OverScrollHeaderStretchConfiguration();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final collapse = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    return builder(context, collapse);
  }

  // The builder reads the screen's state (cover, spinners, name), which
  // changes without the extents changing.
  @override
  bool shouldRebuild(ProfileCoverHeaderDelegate oldDelegate) => true;
}

/// The header itself, for [ProfileCoverHeaderDelegate.builder].
///
/// [topInset] is the status bar height when the header draws behind it (the
/// Profile tab); pushed pages already sit below the status bar and pass 0.
/// [collapse] runs from 0 (expanded) to 1: the cover's controls fade out over
/// the first half and the toolbar fades in over the last 40%, so they never
/// overlap.
class ProfileCoverHeader extends StatelessWidget {
  const ProfileCoverHeader({
    super.key,
    required this.collapse,
    required this.expandedHeight,
    required this.topInset,
    required this.coverUrl,
    required this.name,
    required this.username,
    required this.avatar,
    this.coverOverlay,
    this.coverLeading,
    this.coverActions = const [],
    this.toolbarLeading,
    this.toolbarActions = const [],
  });

  final double collapse;
  final double expandedHeight;
  final double topInset;
  final String? coverUrl;
  final String name;
  final String username;

  /// [profileCoverAvatarSize] square: usually a [ProfileCoverAvatar].
  final Widget avatar;

  /// Centered between the top and the identity row (e.g. "Add cover photo").
  final Widget? coverOverlay;

  /// Round buttons on the cover (see [ProfileCoverButton]).
  final Widget? coverLeading;
  final List<Widget> coverActions;

  /// Toolbar buttons once collapsed, in the theme's ink color.
  final Widget? toolbarLeading;
  final List<Widget> toolbarActions;

  /// Fades a part of the header. Once mostly faded it takes no taps and is
  /// left out of semantics, so the cover's and the toolbar's buttons are never
  /// both reachable.
  static Widget _fade(double opacity, Widget child) {
    final hidden = opacity < 0.5;
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: Opacity(opacity: opacity, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final coverOpacity = 1 - (collapse / 0.5).clamp(0.0, 1.0);
    final toolbarOpacity = ((collapse - 0.6) / 0.4).clamp(0.0, 1.0);
    final screen = MediaQuery.sizeOf(context);
    final decodeWidth = (screen.width * MediaQuery.devicePixelRatioOf(context)).round();
    final url = coverUrl;

    final header = LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        // How far the bottom edge has moved from the expanded layout: up
        // while collapsing, down while stretched by an overscroll.
        final shift = height - expandedHeight;
        final identityTop = expandedHeight - _identityBottom - profileCoverAvatarSize;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // The photo moves up at half the scroll speed and fills the
            // header when it stretches.
            Positioned(
              top: math.min(0.0, shift / 2),
              left: 0,
              right: 0,
              height: math.max(height, expandedHeight),
              child: ColoredBox(
                color: profileNoCoverColor,
                child: url == null
                    ? null
                    : RecipeImageWidget(
                        imageUrl: url,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: decodeWidth,
                      ),
              ),
            ),
            // Scrims: status bar and buttons on top, the name at the bottom.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x61000000), Color(0x00000000)], // 38% → 0
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 150,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xAD000000), Color(0x00000000)], // 68% → 0
                  ),
                ),
              ),
            ),
            if (coverOverlay != null)
              Positioned(
                top: (topInset + identityTop) / 2 - 24 + shift,
                left: 16,
                right: 16,
                child: Center(child: _fade(coverOpacity, coverOverlay!)),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: _identityBottom,
              child: _fade(coverOpacity, _identity()),
            ),
            // 40px circles 12px from the edges; each IconButton lays out at
            // 48 (its tap target), hence the 8px offsets.
            if (coverLeading != null)
              Positioned(
                top: topInset + 8,
                left: 8,
                child: _fade(coverOpacity, coverLeading!),
              ),
            if (coverActions.isNotEmpty)
              Positioned(
                top: topInset + 8,
                right: 8,
                child: _fade(coverOpacity, Row(mainAxisSize: MainAxisSize.min, children: coverActions)),
              ),
            // Collapsed: the whole header fades to `bg` with the name.
            Positioned.fill(
              child: _fade(
                toolbarOpacity,
                ColoredBox(
                  color: t.bg,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: topInset, left: toolbarLeading == null ? 16 : 4, right: 4),
                      child: SizedBox(
                        height: profileCoverToolbarHeight,
                        child: Row(
                          children: [
                            ?toolbarLeading,
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
                              ),
                            ),
                            ...toolbarActions,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // Light status-bar icons on the cover, the theme's once the toolbar takes
    // over. Only matters when the header is behind the status bar.
    if (topInset <= 0) return header;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: toolbarOpacity >= 0.5 ? themeStatusBarStyle(Theme.of(context).brightness) : lightStatusBarStyle,
      child: header,
    );
  }

  /// Avatar with the name and handle beside it, white on the bottom scrim.
  Widget _identity() {
    return Row(
      children: [
        avatar,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                "@$username",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.88)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The avatar on the cover: [profileCoverAvatarSize] with a 3px white ring.
/// [overlay] sits on the photo (e.g. a spinner), [badge] at the bottom right.
class ProfileCoverAvatar extends StatelessWidget {
  const ProfileCoverAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.overlay,
    this.badge,
  });

  final String? avatarUrl;
  final String name;
  final Widget? overlay;
  final Widget? badge;

  /// Size of the photo inside the ring.
  static const double photoSize = profileCoverAvatarSize - 2 * 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: profileCoverAvatarSize,
      height: profileCoverAvatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: profileCoverAvatarSize,
            height: profileCoverAvatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Stack(
              children: [
                ProfileAvatar(avatarUrl: avatarUrl, name: name, size: photoSize),
                ?overlay,
              ],
            ),
          ),
          if (badge != null) Positioned(right: -2, bottom: 0, child: badge!),
        ],
      ),
    );
  }
}

/// A 40px dark translucent circle with a white icon, on the cover.
class ProfileCoverButton extends StatelessWidget {
  const ProfileCoverButton({super.key, required this.tooltip, required this.onPressed, required this.icon});

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final background = Colors.black.withValues(alpha: 0.35);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: background,
        disabledBackgroundColor: background,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
      ),
    );
  }
}
