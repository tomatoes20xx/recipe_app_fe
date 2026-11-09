# Recipe photos: multi-pick + grid with per-photo remove, crop and drag-to-reorder

Follow-up to `docs/create-recipe-redesign.md` (already implemented). Design source: Claude Design canvas, page "Recipe photos", boards **2 · 3-column grid** and **2 · Grid — dragging to reorder** (https://claude.ai/code/artifact/f33c3570-3e44-46bd-a3dc-d3a6b7b647e1). This file is self-contained. Read the root `CLAUDE.md` first.

## Scope

- `lib/recipes/create/photos_section.dart` (rewrite the "with photos" layout; the empty state stays).
- Image handling in `lib/screens/create_recipe_screen.dart` (`_pickImage`, `_removeImage…`, `_existingImages` / `_selectedImages`, edit-mode image sync in `_submit`).
- `lib/recipes/recipe_api.dart` → `addRecipeImage` returns the new image id (see Edit mode).
- New l10n keys. No backend changes. No new dependencies unless justified (see Drag).

Unchanged: 10-photo limit (`_maxImages`, backend also enforces 10), `ImageUtils.compressImage` + 5 MB check, `ImageCropScreen` (4:3), the empty-state button, draft save/restore, preview screen input (it just receives the ordered list).

## 1. One ordered photo list

Today order = `_existingImages` then `_selectedImages`, so a new photo can never go before an uploaded one. Replace both lists with one ordered list, e.g.

```dart
sealed class _Photo { }            // or a small class with a kind enum
class _ExistingPhoto extends _Photo { final RecipeImage image; }
class _LocalPhoto extends _Photo { String path; final String sourcePath; } // path = compressed/cropped file, sourcePath = original pick
```

Keep `_removedImageIds`. Index 0 is the cover. Update every reader: photo count, `canAdd`, preview images, draft `imagePaths` (local photos in list order), `_hasMeaningfulData`, edit-mode prefill, and the create-mode upload list (files in list order — confirm the create endpoint stores them in the order sent).

## 2. Adding photos (multi-pick)

The add actions (empty-state button and the grid's "+" tile) call a new `_pickImages()`:

- `remaining = _maxImages - count`. If `remaining >= 2`: `_imagePicker.pickMultiImage(imageQuality: 85, limit: remaining)` (image_picker 1.2.1 supports `limit`). If `remaining == 1`: fall back to `pickImage` (`limit` must be ≥ 2). If 0 the "+" tile isn't shown.
- If the platform returns more than `remaining` (some Android pickers ignore `limit`), keep the first `remaining` and show one snackbar: **photosSkippedLimit** ("{n} ფოტო არ დაემატა — მაქსიმუმ 10").
- **No crop step.** For each file in order: `ImageUtils.compressImage` → 5 MB check (same rules/messages as today) → append `_LocalPhoto(path: compressed, sourcePath: original)`. Process sequentially; while processing, show one placeholder tile per pending photo (`field` bg, 20px `brandInk` spinner) in its final grid slot.
- Failures are aggregated into one snackbar after the batch: **photosSkippedTooLarge** ("{n} ფოტო ძალიან დიდი იყო და გამოტოვებულია"), or the existing compression-failed message when n = 1.
- Trigger the debounced draft save after a batch.

## 3. Grid layout (with ≥ 1 photo)

Section header caption: "{count} / 10" (replaces "{n} ფოტო").

Grid: 3 equal columns, 8 px gaps, square cells (cell = (width − 16) / 3). **The first photo (cover) spans 2×2**; the rest flow left→right, top→bottom around it (cells 2 and 3 fill the right column beside the cover, then full rows of 3). The "+" tile is the last cell, hidden at 10 photos.

Tile (radius 14, `BoxFit.cover`, file or network image):
- **✕ remove**: top-right, 6 px inset, 30 px circle, black 55 %, white ✕ 13 px; hit area ≥ 44 px. Removes immediately (existing photos → add id to `_removedImageIds`). No confirm dialog; show a snackbar with **Undo** for 4 s that restores the photo at its old index (and drops the id from `_removedImageIds`).
- **Crop**: bottom-right, same style, crop icon 14 px — **only on local photos** (uploaded photos in edit mode can't be re-cropped here; show ✕ only). Opens `ImageCropScreen.show(context, File(sourcePath), aspectRatio: 4/3)` → compress → replace that photo's `path` (keep `sourcePath`, so re-cropping starts from the original). Cancel = no change.
- **Cover badge**: on index 0 only, bottom-left 10 px inset: "გარეკანი" 12 w700 white on black 60 %, radius 8, padding 4/10.
- Uncropped photos are uploaded as picked; the grid shows them center-cropped (`BoxFit.cover`).

"+" tile: `card` bg, 1.5 px dashed `dashed` border, radius 14, `brandInk` + icon 22 and "დამატება" 12 w600.

Hint under the grid, 12 px `ink2`: **photosReorderHint** "დაიჭირე და გადაათრიე თანმიმდევრობისთვის · პირველი — გარეკანი". Hide when there's only one photo.

## 4. Drag to reorder

- Long-press (~300 ms) on a photo tile lifts it: scale 1.06, rotate −4°, shadow (0 14 30, black 22 %), `HapticFeedback.mediumImpact()`.
- While dragging: hide ✕/crop on all tiles and the "+" tile can't be a target; the hint text switches to **photosDropHint** "გაუშვი სასურველ ადგილას · პირველ ადგილზე — გარეკანი"; the slot where it would land shows a dashed 2 px `brand` border on `soft`; other tiles animate to their new positions (~200 ms, ease-out). Dropping into slot 0 makes it the cover (it becomes the 2×2 tile).
- Drop outside / cancel → snaps back. Drop commits the new order, then debounced draft save.
- Implementation: Flutter has no reorderable grid, and the 2×2 first cell rules out most grid packages. Prefer a small custom `Stack` with positions computed from index (`AnimatedPositioned`) plus `LongPressDraggable`/`DragTarget` (or pointer handling). If you use a package instead, it must handle the 2×2 first cell; justify it and keep it to one dependency.
- Scrolling: the form must not scroll while a drag is active; auto-scroll isn't needed (the grid is ≤ 4 rows).
- **Accessibility**: each tile gets semantics custom actions **moveEarlier** ("Move earlier" / "წინ გადატანა"), **moveLater** ("Move later" / "უკან გადატანა"), **makeCover** ("Make cover" / "გარეკანად დაყენება"), so reordering works without dragging. Label each tile "ფოტო {n}" (+ ", გარეკანი" for the first).

## 5. Edit mode sync (`_submit`)

New photos can now sit anywhere in the order, so the final order must include their ids:

1. Delete `_removedImageIds` (as now).
2. Upload local photos **in list order** via `addRecipeImage`. Change it to return the created image id — the backend's `POST /recipes/:id/images` already responds 201 with `{ id, url, width, height, sort_order }`; parse it.
3. Build the full id list from the unified list (existing ids + the ids returned in step 2, each at its list position) and call `reorderRecipeImages` once. Skip if the order is already 1…n as uploaded.
4. Keep today's tolerance (one failed upload doesn't abort the rest), but if an upload failed, call reorder with only the ids you have and show the existing error/status message.

## Localization

Add getter + `en` + `ka` (check for existing keys first, e.g. a cover label from the previous redesign):
photoCount ({count} / {max}), cropPhoto (Crop / მოჭრა), removePhoto (Remove photo / ფოტოს წაშლა), photoRemoved (Photo removed / ფოტო წაიშალა), undo (Undo / დაბრუნება), photosReorderHint, photosDropHint, photosSkippedLimit ({n} photos weren't added — max {max} / {n} ფოტო არ დაემატა — მაქსიმუმ {max}), photosSkippedTooLarge ({n} photos were too large and were skipped / {n} ფოტო ძალიან დიდი იყო და გამოტოვებულია), processingPhotos (Processing photos… / ფოტოების დამუშავება…), moveEarlier, moveLater, makeCover, photoLabel (Photo {n} / ფოტო {n}).

## Acceptance checks

- `flutter analyze` passes with no new warnings; light and dark use `AppTokens`.
- Create: pick 6 in one go → all appear without a crop screen; crop two of them; re-crop one (starts from the original); remove one, undo; add 5 more → only 4 added + limit snackbar; publish → recipe shows photos in the on-screen order, first is the cover.
- An oversized photo in a batch is skipped with one aggregated message; the rest are added.
- Drag: move photo 5 into slot 0 → it becomes the 2×2 cover with the badge; drag + drop outside snaps back; the form doesn't scroll mid-drag; TalkBack/VoiceOver "Make cover" works.
- Edit an existing recipe: uploaded photos show ✕ but no crop; add 2 new photos and drag one before the old cover → after saving, the recipe's order matches the screen (new photo is the cover).
- Draft: pick photos, reorder, kill the app, reopen → "Draft found" restores the same photos in the same order.
- Final summary: what changed, anything left unused.
