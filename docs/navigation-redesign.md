# Navigation redesign: remove the side drawer

Design source (Claude Design canvas): https://claude.ai/code/artifact/f33c3570-3e44-46bd-a3dc-d3a6b7b647e1
Boards: "Home — feed tabs", "Home — sort sheet open", "Profile tab", plus dark variants.
This file is the implementation spec; it is self-contained if the canvas is not reachable.

## Summary

The drawer (`_FeedShellDrawer` in `lib/screens/feed_shell_screen.dart`) mixes feed filters with navigation. Split it:

1. **Feed scope + sort → top of the Home feed.** 4 equal tabs + a sort pill that opens a bottom sheet.
2. **Menu button → Profile tab** (5th bottom-nav item, the user's avatar). Profile, streak, library (saved, shopping list, shared) live there.
3. **Settings / Help / Sign out** → reached from a gear icon on the Profile tab (existing `SettingsScreen`; add Sign out to it).
4. The drawer is removed entirely.

Feed recipe cards, recipe detail, search, notifications and create screens are **out of scope** — do not restyle them. The cards in the mock are illustrative only.

## Constraints

- Surgical: only touch what this spec needs. Do not change the global `ThemeData`/`ColorScheme` in `main.dart`; other screens must look the same as before.
- Reuse existing screens/controllers (`ProfileScreen`, `SettingsScreen`, `SavedRecipesScreen`, `ShoppingListScreen`, `SharedRecipesScreen`, `SharedShoppingListsScreen`, `HelpAndSupportScreen`, `FeedController`, `StreakController`, `ShoppingListController`, notification controller).
- Follow repo conventions (see root `CLAUDE.md`): no state library, constructor-passed controllers, all strings in `lib/localization/app_localizations.dart` (getter + `en` + `ka`).
- Remove code that this change orphans (drawer widgets, helper classes, unused imports, unused l10n getters only if nothing else uses them). Mention other dead code instead of deleting it.
- Done = `flutter analyze` clean + manual checks at the end of this file.

## Design tokens

Used only by the new/changed widgets (bottom nav, feed header, sort sheet, profile tab sections). Pick light/dark from `Theme.of(context).brightness`. Put them in one small place (e.g. a private const class or a `ThemeExtension` next to the theme code) — whichever is less code.

| Token | Light | Dark | Use |
|---|---|---|---|
| bg | `#F6F7F5` | `#0F1311` | screen background |
| card | `#FFFFFF` | `#181D1A` | cards, bottom nav, inactive chip |
| sheet | `#FFFFFF` | `#1C221E` | bottom sheet |
| ink | `#17211B` | `#EDF1EE` | primary text, icons |
| ink2 | `#5A665F` | `#A2ADA6` | secondary text, inactive icons |
| line | `#E3E8E4` | `#2B332E` | 1px borders, dividers |
| brand | `#53B175` | `#53B175` | tab underline, active dot, radio, avatar ring (never as text color) |
| brandInk | `#2C7A4B` | `#7ED19D` | green text / icons on bg, card, soft |
| soft | `#E7F4EC` | `#1C3125` | active chip bg, icon tiles, avatar placeholder |
| fill | `#3F9E64` | `#3F9E64` | "+" button bg, completed streak day (white icon on it) |
| badge | `#C93C3C` | `#C93C3C` | notification count bg (white text) |
| scrim | `rgba(16,22,18,.45)` | `rgba(0,0,0,.6)` | sheet barrier |

Why not `#53B175` for text: it is ~2.6:1 on white and fails contrast. Use brandInk for any green text.

Type: the app already falls back to Noto Sans Georgian. Sizes below are logical px. Radii: chips/pills 18 (fully round at 36 height), cards 16–20, icon tiles 12–14, sheet top 24.
Icons: Material rounded/outlined equivalents of the mock's line icons (home, search, add, notifications, settings, share, bookmark, shopping cart, share/people, list, chevron, swap_vert for sort, local_fire_department for streak). Touch targets ≥ 44×44.

## 1. Bottom navigation (`_BottomShellNavBar`)

Order changes to: **Home · Search · Add · Notifications · Profile** (was Home · Notifications · Add · Search · Menu).

- Height 64 + bottom safe area, bg `card`, top border 1px `line`. 5 equal slots, icons only (24px), each with a semantic label (existing l10n: `home`, `search`, `notifications`, `profile`, add-recipe label already used).
- Active item: icon in `brandInk` (filled variant for Home), plus a 4×4 `brand` dot 4px below the icon. Inactive: `ink2`, outlined.
- Add: 48×40 rounded-rect (radius 14) bg `fill`, white "+" 22px. Behaviour unchanged (verified account + ban dialog + push `CreateRecipeScreen`).
- Notifications: badge pill (min 18×18, radius 9, `badge` bg, white 11px bold, 2px `card` border) at icon top-right; reuse `unreadCount`. Hide at 0.
- Profile: 28px circular avatar (user's avatar image; fallback = initial on `soft` with `brandInk` text). Inactive ring 1.5px `line`; active ring 2px `brand` + dot. Guests: generic person icon.
- `IndexedStack` gains a 4th page for the Profile tab. Page indices must be updated wherever `_setPage` / `_currentIndex` / notification deep links use them.
- Keep the `GlobalKey`s used by `services/app_tour_service.dart`; the `menuKey` target becomes the Profile item. Update tour step 6 copy (`tourMenuTitle` / `tourMenuDescription`, en + ka) to describe the Profile tab: saved recipes, shopping list, settings. Remove the 📱 emoji while editing it.

## 2. Home feed header (`home_screen.dart`)

Top to bottom, bg `bg`:

**a) Title row** (height 44, horizontal padding 16): "Yummy" wordmark left (24px, weight 800, `brandInk`). Right: streak chip — height 36, radius 18, bg `soft`, flame icon 18 + `currentStreak` number (14px bold, `brandInk`). Tapping it switches to the Profile tab. Hide the chip for guests and when streak is 0.

**b) Scope tabs** — 4 **equal-width** tabs in one row (no horizontal scrolling, no scrollbar), horizontal padding 8, bottom border 1px `line`:

| Tab | l10n | FeedScope |
|---|---|---|
| შენთვის / For you | **new** `feedTabForYou` | `global` |
| გამოწერილი | `following` | `following` |
| პოპულარული | `popular` | `popular` |
| ტრენდული | `trending` | `trending` |

Text 14px, centered, single line, ellipsis on overflow. Active: `ink`, weight 700, 3px `brand` underline flush with the bottom border. Inactive: `ink2`, weight 500. Tap → see behaviour table.

**c) Filter row** (padding 12 vertical, 16 left): sort pill, then a 1×24 `line` divider, then the category chips.
- Sort pill (fixed, does not scroll): height 36, radius 18, 1px `line` border, bg `card`, `swap_vert` 16 + current option label (13px, 600, `ink`) + chevron-down 16. Opens the sort sheet (section 3).
- Category chips: replace the current `FilterChip`s in `_buildCategoryChips` with plain pills (no icons): height 36, radius 18, padding 0 14, 13px. Selected: bg `soft`, text `brandInk` 700, no border. Unselected: bg `card`, 1px `line`, text `ink2` 500. First chip "ყველა" (`all`) = no category. Keep existing `feed.setCategory` behaviour and category list.
- The chip list scrolls horizontally **with no visible scrollbar**, and fades out over the last 48px on the right edge (`ShaderMask` with a linear gradient) to hint at more content. Right padding 40 so the last chip can scroll fully clear of the fade.

The header scrolls away with the feed or stays pinned — keep whatever the current home screen does with its chips.

## 3. Sort / period bottom sheet

`showModalBottomSheet`, bg `sheet`, top radius 24, barrier `scrim`, padding 8/20/34(+safe area). Drag handle 36×4 `line`, radius 2, centered, 14 below.
Header row: title (18px bold `ink`) left, current tab name (13px `ink2`) right.
Then one row per option: min height 60, bottom border 1px `line`; label 15px `ink` (700 if selected, else 500); optional description 13px `ink2` below; trailing 22px radio (selected: `brand` 7px ring; unselected: 2px `ink2` at 60% opacity). Tap = apply + close.

| Tab | Sheet title | Options (label → controller) | Description |
|---|---|---|---|
| შენთვის | **new** `sortSheetTitle` "Sort"/"დალაგება" | `feedSortDiscovery` → sort=discovery · `recent` → recent · `top` → top | **new** `sortDiscoveryDesc` "Recipes you haven't seen yet"/"რეცეპტები, რომლებიც ჯერ არ გინახავს"; `sortRecentDesc` "Most recently added"/"ბოლოს დამატებული რეცეპტები"; `sortTopDesc` "Most liked recipes"/"ყველაზე მოწონებული რეცეპტები" |
| გამოწერილი | `sortSheetTitle` | `recent` → recent · `top` → top | `followingRecentDesc` "New recipes from people you follow"/"გამოწერილი ავტორების ახალი რეცეპტები"; `followingTopDesc` "Their most liked recipes"/"მათი ყველაზე მოწონებული რეცეპტები" |
| პოპულარული | **new** `periodSheetTitle` "Period"/"პერიოდი" | `allTime`, `last30Days`, `last7Days` → `popularPeriod` | none |
| ტრენდული | `periodSheetTitle` | `last7Days` → trendingDays=7 · `last30Days` → 30 | none |

The sort pill shows the selected option's label for the active tab.

## Behaviour: tabs ↔ FeedController

Use the existing API (`lib/feed/feed_controller.dart`): `setScopeAndOptions`, `setSort`, `setPopularPeriod`, `setTrendingDays`.

- Tab tap → `setScopeAndOptions(newScope: …)`. Following does not support `discovery`: when switching to Following while `sort == discovery`, pass `newSort: FeedSort.recent` (same as the drawer did). Switching back to For you keeps the current sort.
- Sheet option → the matching setter. Must reload the feed exactly as the drawer options did (compare with `_selectOption` in the drawer, including any `onNavigateToFeed`/scroll-to-top it does).
- Following tab for guests: run the same account-required flow the drawer used for Following (check `_FeedShellDrawer`); keep the tab visible.
- Initial state comes from the controller (default global + discovery), so the active tab and pill label are always derived from `feed.scope` / `feed.sort` / `feed.popularPeriod` / `feed.trendingDays` — no duplicated UI state.

## 4. Profile tab (new 4th page)

Prefer reusing `ProfileScreen` for the signed-in user (it already renders header, stats, streak and the user's recipes) and adding the library section to it when shown as the own-profile tab — e.g. a constructor flag like `isTabRoot` — rather than duplicating it. If that is clearly messier than a new screen, make a new screen that reuses `ProfileScreen`'s pieces, and say why.

Layout (bg `bg`, horizontal padding 16, 24 between sections), scrollable, bottom padding clears the nav:

1. **App bar** (height 44, no back button): title `profile` (20px bold) left; right: share-profile icon button (only if sharing already exists for profiles, otherwise omit) and gear → `SettingsScreen`.
2. **Identity**: 72px avatar with 3px `bg` gap + 2px `brand` ring; to its right display name (20px bold) and `@username` (14px `ink2`).
3. **Stats card**: 3 equal cells in one `card` container (1px `line`, radius 16), separated by 1px `line` verticals: number 18px bold `ink`, label 12px `ink2` — recipes / `followers` / `following`. Followers and Following open the existing followers/following screens (respect the privacy settings already handled there).
4. **Edit profile** button: full width, height 44, radius 12, 1px `line`, bg `card`, 14px 600 `ink` → existing edit-profile flow (`editProfile`).
5. **Streak card** (`card`, 1px `line`, radius 20, padding 16): 44px `soft` tile with flame (`brandInk`) + title "{n}-დღიანი სერია" (16px bold) + subtitle **new** `streakKeepGoing` "Keep your streak going today"/"გააგრძელე სერია დღესაც" (13px `ink2`). Below: 7 day cells for the current week (Mon→Sun, short weekday names via `DateFormat.E(locale)`, 11px; today 700 `ink`, others `ink2`). Day dot 30px: completed = `fill` + white check; today not yet done = 2px dashed `brand` ring; other = `bg` + 1px `line`. Derive completed days from `StreakController.currentStreak` (consecutive days ending today or yesterday — check the streak API/`updateFromCook` to see whether today counts). If the data can't support the week strip reliably, ship the card without it and note it. Use a **new** `streakNDays`-style key without the 🔥 emoji (the existing `streakDaysLabel` has one) — reuse `streakNDays` if its wording fits.
6. **Library** — section label `library` (13px 600 `ink2`). Then:
   - 2 tiles side by side (`card`, 1px `line`, radius 18, padding 16): 40px `soft` icon tile (`brandInk` icon) above title (15px bold) and count (13px `ink2`). Saved (`savedRecipes`, `nSaved`) → `SavedRecipesScreen`; Shopping list (`shoppingList`, `{count} items`) → `ShoppingListScreen`.
   - A grouped list card (radius 18) with two 56px rows, `line` divider between: icon (`ink2`) · label 15px 500 · count `ink2` · chevron. `sharedRecipes` → `SharedRecipesScreen`; `sharedShoppingLists` → `SharedShoppingListsScreen`.
   - Copy the navigation, counts loading and account checks from `_buildLibraryGrid` (counts source, `_closeAndRequireAccount` reasons), minus the drawer-closing part.
7. **My recipes** — header row: **new** `myRecipes` "My recipes"/"ჩემი რეცეპტები" + count, and `seeAll` link (`brandInk`) on the right. 2-column grid of the user's recipes (image radius 16, 132 tall, title 14px 600 below). If `ProfileScreen` already lists them, reuse its list/grid.

**Guest state**: replace sections 2–5 with a sign-up card (reuse `guestDrawerTitle` / `guestDrawerBody` + the existing sign-in CTA from `_buildGuestHeader`). Library tiles stay visible and use the existing account-required prompts. Gear still opens settings.

## 5. Settings

`SettingsScreen` already has Help & support. Add **Sign out** (signed-in only) at the bottom, reusing `_confirmSignOut` logic from the drawer (move it, don't duplicate). Style it like the existing settings rows; destructive text color only if the screen already has a convention (e.g. delete account).

## Removal

- Remove `drawer:` from the shell `Scaffold`, `_scaffoldKey.openDrawer` usage, `_FeedShellDrawer` and its state, `_BottomDrawerButton`, the drawer-only scope/option widgets and `_SectionHeader` if unused elsewhere.
- Keep any drawer logic the new UI needs by moving it (counts loading, sign-out confirm, account-required helpers), not copying.
- Grep for other `openDrawer` callers or drawer-only l10n keys and list what became unused in your final summary.

## Accessibility

- Every icon-only button has a `Semantics`/`tooltip` label. Tabs and chips expose selected state.
- Contrast: use `brandInk` (not `brand`) for green text. Badge white on `#C93C3C` is fine.
- Respect text scaling: tab labels ellipsize; rows grow vertically.

## Acceptance checks

- `flutter analyze` passes with no new warnings.
- Light and dark both match the token table.
- Switching tabs and sheet options loads the same data the old drawer options did (all 10 combinations: 3 global, 2 following, 3 popular, 2 trending).
- Following tab as guest triggers the account prompt.
- No horizontal scrollbar is visible anywhere in the header; chips fade at the right edge.
- Bottom-nav order Home · Search · Add · Notifications · Profile; notification badge and deep links still land on the right page.
- Profile tab: library counts, all four library destinations, settings, sign out (from Settings), edit profile, followers/following, guest state.
- App tour runs and its last step highlights the Profile item with the updated copy.
- Category filtering still works and "ყველა" clears it.
