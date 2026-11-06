# Own-profile cleanup (follow-up to navigation-redesign.md)

Read `docs/navigation-redesign.md` first; tokens (`lib/theme/app_tokens.dart`) and conventions there still apply.
This spec **supersedes items 2 and 7 of section 4 (Profile tab)** in that file.

## Problem

There are two "own profile" screens:

- the new `ProfileTabScreen` (`lib/screens/profile_tab_screen.dart`), and
- `ProfileScreen` in self mode (`username == null`, `_isSelf`), now reachable only from the tab ("See all" and tapping the identity row → `_openFullProfile`).

They repeat: avatar/name/handle, stats, Edit profile, streak, the recipe grid, and Saved (library tile on the tab, "Saved" tab on the old screen).
Only the old screen has: avatar change, cover photo, total likes received, Liked recipes, and the ban/violation banners.

## Target

1. **Profile tab** is the only own-profile screen. It gains avatar + cover photo editing (same behaviour as the old screen) and the ban banners.
2. **New "Recipes" screen** (`MyRecipesScreen`) opened from "See all": the user's full recipe grid, the Liked recipes list, and total likes received.
3. **`ProfileScreen` becomes other-users only**: all self-mode code is removed.

Behaviour must match the old screen for everything that moves. **Move code, don't copy it** — after this change each piece (avatar upload/delete, cover menu/picker, `_CoverPhotoGrid`, `_BanBanner`) has exactly one home.

## 1. Profile tab changes

### Header: cover + avatar (replaces the identity row)

Order inside the scroll view (16px side padding):

1. **Ban banner** (moved `_buildBanBanners` + `_BanBanner`, same conditions and copy: permanent ban, soft ban until date, violation warnings at counts 2 and 5). Only shown when one applies; 16px gap below. Keep its existing colors.
2. **Cover** — full width, height 132, radius 20, `BoxFit.cover`, cached image like the old screen.
   - No cover: `soft` background, no text.
   - Camera button, bottom-right, 12px inset: 36px circle, `Colors.black` at 45% opacity, white `photo_camera` 18px; semantics label `changeCoverPhoto` / `addCoverPhoto`. Shows a 16px white spinner while `_isSettingCover`; disabled meanwhile.
   - Tap → the moved `_showCoverPhotoMenu` (add/change → `_CoverPhotoGrid` picker of the user's own recipe photos; remove when a cover exists). Keep the "upload a recipe with a photo first" (`noRecipesForCover`) guard and success/error toasts.
   - Restyle the menu sheet only to match the tab: `sheet` bg, top radius 24, drag handle as in the sort sheet; destructive row in the theme's error color as before.
3. **Avatar** — 80px `ProfileAvatar`, 3px `bg` gap + 2px `brand` ring (as now), overlapping the cover's bottom edge by 40px, left edge 16px inside the cover.
   - Camera badge at the avatar's bottom-right: 28px circle, `fill` bg, white `photo_camera` 15px, 2px `bg` border; semantics label `updateAvatar` (or `addAvatar` when none). Spinner while uploading/deleting.
   - Tapping the avatar **or** the badge → the moved `_showAvatarMenu` (add / update / delete) → existing `_uploadAvatar` (gallery → `ImageCropScreen` 1:1 → `ImageUtils.compressAvatar` → `AuthApi.uploadAvatar` → `auth.bootstrap()`) and `_deleteAvatar`. Same toasts.
4. **Name + handle** to the right of the avatar, top-aligned with the cover's bottom edge + 8px (they sit below the cover, beside the overlapping avatar): name 20px bold `ink`, `@username` 14px `ink2`, max 2/1 lines with ellipsis. **Not tappable** any more.

Then stats card, Edit profile, streak, library, My recipes — unchanged except below.

### Other tab changes

- Delete `_openFullProfile`. Nothing on the tab opens `ProfileScreen` for yourself.
- Stats card: the **recipes** cell becomes tappable → `MyRecipesScreen` (Mine). Followers/Following unchanged. Total likes is **not** added here; it lives on the Recipes screen.
- My recipes section: keep the preview grid (6 items). "See all" (`seeAll`) → `MyRecipesScreen` (Mine). Hide "See all" when the user has 0 recipes.
- After returning from `MyRecipesScreen`, refresh the tab's recipe preview and counts if anything changed (e.g. a recipe was deleted from the detail screen) — mirror how the tab already decides to refresh in `_load`.
- Pull to refresh also reloads the cover photo (it comes from `getUserProfile`).

## 2. New `MyRecipesScreen` (`lib/screens/my_recipes_screen.dart`)

Constructor: `auth`, `apiClient`, `shoppingListController`, `username`, `initialTab` (0 = mine, 1 = liked). Pushed with `MaterialPageRoute`.

Layout, bg `bg`:

1. **App bar**: back button, title `recipes` (18px bold `ink`), no actions. Flat, bg `bg`.
2. **Summary card** (16px side padding, `card`, 1px `line`, radius 16): 2 equal cells with a 1px `line` divider, same style as the Profile tab's stats card — `recipesCount` with label `recipes`, and `totalLikesCount` with label `totalLikes` ("მოწონებები"; likes received on your recipes). Both from `UserApi.getUserProfile(username)`, loaded by this screen. Not tappable.
3. **Tabs**: 2 equal-width underline tabs styled exactly like the Home feed scope tabs (14px, active `ink` 700 + 3px `brand` underline, inactive `ink2` 500, bottom border 1px `line`): `myRecipes` | `profileTabLiked`. Use a `TabController`; keep each tab's scroll position.
4. **Grid** per tab: 2 columns, 16px side padding, 12px column gap, 16px row gap, reusing the tab's recipe tile. Move `_RecipeTile` from `profile_tab_screen.dart` to `lib/widgets/common/recipe_grid_tile.dart` (public `RecipeGridTile`) so both screens use one widget.
   - Mine: `UserRecipesController(username)`. Liked: `LikedRecipesController` (moved out of `ProfileScreen`; it only existed for self mode).
   - Infinite scroll via the controllers' `loadMore` (follow the pattern `ProfileScreen` uses with its scroll listener), pull to refresh reloads the active list + summary.
   - Loading: centered `CircularProgressIndicator` in `brandInk`. Error: retry button as on the tab.
   - Empty: existing `EmptyStateWidget` with the old copy — Mine: `noRecipesYet` / `createYourFirstRecipe`; Liked: `noLikedRecipesYet` / `likedRecipesEmptyDescription`.
   - Tap → `RecipeDetailScreen`. On return, refresh the list if the old screen did so in the same case (check how `ProfileScreen` handled a deleted/unliked recipe).

No new l10n keys should be needed (all keys above exist). If one is missing, add getter + `en` + `ka`.

## 3. `ProfileScreen` → other users only

- Make `username` required; delete `_isSelf` and every self-only branch: `_loadOwnProfile`, avatar upload/delete + menu, cover menu/picker + `_CoverPhotoGrid` (moved), streak controller + `_StreakChip`, email row, `_SelfActionRow`, ban banners (moved), liked/saved controllers, the 3-tab `TabController` and `_buildTabBar` if only self mode used them, self-only empty states, `_isUploading`/`_isDeleting`/`_isSettingCover`.
- Viewing **your own username** (e.g. tapping your name on a feed card) keeps today's public view — that is how others see you. Don't change it in this task.
- Remove imports and l10n getters that become unused (only if nothing else uses them). List anything you were unsure about instead of deleting it.

## Acceptance checks

- `flutter analyze` passes with no new warnings.
- `grep -n "_isSelf" lib/screens/profile_screen.dart` returns nothing; `ProfileScreen(` is never constructed without `username`.
- Profile tab: add/change/remove cover (picker shows own recipe photos; guard when none), add/update/delete avatar (crop 1:1), spinners, toasts, light + dark.
- Ban/violation banners appear on the Profile tab for the same account states as before.
- "See all" and the recipes stat open the Recipes screen; summary shows recipes + likes received; both tabs paginate, refresh and show empty states; back to the tab reflects changes.
- Another user's profile looks and behaves exactly as before (follow, block, report, recipes grid, cover, bio).
- Final summary lists what was moved, what was deleted, and anything left unused.
