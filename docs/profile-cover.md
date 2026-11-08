# Profile tab: immersive cover (variant C)

Follow-up to `docs/navigation-redesign.md` and `docs/profile-cleanup.md`; tokens in `lib/theme/app_tokens.dart` and the conventions there still apply.
Design source: Claude Design canvas, board "C · Immersive, name on cover" (https://claude.ai/code/artifact/f33c3570-3e44-46bd-a3dc-d3a6b7b647e1). This file is self-contained.

**Scope:** only the signed-in header of `ProfileTabScreen` (`lib/screens/profile_tab_screen.dart`): `_buildAppBar`, `_buildHeader`, ban-banner placement, and the scroll container. Everything below the header (stats, edit profile, streak, library, my recipes), the guest state, the cover/avatar menus and upload logic, and `ProfileScreen` (other users) stay as they are. Reuse the existing handlers (`_showCoverPhotoMenu`, `_showAvatarMenu`, `_isSettingCover`, `_isUploading`/`_isDeleting`) — don't duplicate them.

## Layout (signed in)

The cover becomes a full-width hero that starts at the very top of the screen (behind the status bar). The separate app bar row (title "პროფილი" + gear) is removed for signed-in users; its actions move onto the cover.

### Cover (expanded height 300 incl. status bar area)

- Full bleed: no side margins, no radius. Image `BoxFit.cover`, cached like now.
- **Top scrim** for button/status-bar legibility: linear gradient black 38% → 0%, top 100px.
- **Bottom scrim** for the identity text: linear gradient black 0% → 68%, bottom 150px.
- **No cover photo:** solid `#2C5E40` (same in light and dark; white text on it is ~7:1). Centered in the area above the identity block, a pill button: height 40, radius 20, 1px white at 70% border, white text 14px 600 + camera icon 18, label `addCoverPhoto` → `_showCoverPhotoMenu`. Hide this pill when a cover exists. Scrims stay (harmless on the solid color).

### Floating actions (top-right)

At `safeTop + 12`, right 12, 8px apart, three 40×40 circles, `Colors.black` 35% bg, white icons 19–20px, each with a semantics label/tooltip:
1. Camera → `_showCoverPhotoMenu` (label `changeCoverPhoto` / `addCoverPhoto`). While `_isSettingCover`: 16px white spinner, disabled.
2. Share profile — only if profile sharing already exists in the app; otherwise omit (same rule as before).
3. Gear → `SettingsScreen` (moved from the old app bar).

### Identity block (bottom-left, on the cover)

Row at left 16, right 16, bottom 18, gap 14, vertically centered:
- **Avatar** 76px, 3px white border (replaces the 3px bg gap + brand ring on the cover version). Tap → `_showAvatarMenu`. Camera badge at bottom-right (offset right −2, bottom 0): 28px circle, `fill` bg, 2px white border, white camera 13px; spinner while uploading/deleting.
- **Name** 24px w700 white, max 2 lines ellipsis; **@username** 14px white 88% opacity, 1 line. Not tappable.

### Below the cover

- Ban/violation banner (if any) moves to directly **below** the cover: 16px top padding, then the banner, then the existing content.
- Existing content keeps its 16px side padding; first item (stats card) starts 16px below the cover. Section gaps unchanged.

## Scrolling and status bar

Use a `CustomScrollView` with a pinned, collapsing header (e.g. `SliverAppBar(pinned: true, expandedHeight: 300, …)` with the cover in `flexibleSpace`), and the rest as slivers. Requirements:

- **Expanded:** cover fills the area behind the status bar; status-bar icons are **light**.
- **Collapsed** (scrolled past the cover): a 56px toolbar in `bg` with the name (16px w700 `ink`, 1 line) on the left and the gear in `ink` on the right; no camera/share; status-bar icons follow the theme (dark icons in light mode, light in dark mode). Fade between the two states; no hard jump.
- The floating buttons and identity block fade out as the header collapses (they must not overlap the toolbar).
- Pull-to-refresh still works and reloads the cover (`RefreshIndicator` placed so its spinner appears below the status bar, e.g. via `edgeOffset`).
- The status-bar style must only apply while the Profile tab is visible (it lives in the shell's `IndexedStack`); Home/Search/Notifications keep their current status-bar style.

If `SliverAppBar` fights the design, an equivalent hand-rolled `SliverPersistentHeader` is fine — say which you chose and why.

## Guest state

Unchanged: keep the current app bar (title + gear) and guest card. The immersive cover is signed-in only.

## Acceptance checks

- `flutter analyze` passes with no new warnings.
- Light and dark: cover with photo, without photo (solid green + "add cover" pill), bright and dark photos both keep text and buttons readable.
- Cover camera → same menu as before (pick from own recipe photos, remove); avatar tap/badge → same avatar menu; spinners and toasts as before.
- Scroll down: header collapses to the `bg` toolbar with name + gear; status-bar icons switch correctly; scroll back up restores the cover.
- Switching to another tab and back doesn't leave light status-bar icons on Home/Search/Notifications.
- Ban banner appears below the cover for affected accounts.
- Guest Profile tab looks exactly as before.
- Final summary lists what changed and anything left unused.
