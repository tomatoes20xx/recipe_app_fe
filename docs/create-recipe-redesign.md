# Create / edit recipe redesign: option A ("one page, clear sections")

Design source: Claude Design canvas, page "Recipe creation", boards **A1 · One page — empty**, **A2 · One page — filled**, **Shared · Tag picker sheet**, **Shared · Preview before publish** (https://claude.ai/code/artifact/f33c3570-3e44-46bd-a3dc-d3a6b7b647e1). This file is self-contained.
Read the root `CLAUDE.md` and `docs/navigation-redesign.md` (tokens, conventions) first.

## Scope

Restyle and restructure `lib/screens/create_recipe_screen.dart` (create **and** edit mode), add a tag-picker sheet and a preview screen.

**Behaviour that must not change:** what gets sent to the API (create, update, image add/delete/reorder in edit mode), validation rules in `_submit`, draft save/restore (`RecipeDraftService`, the "Draft found" dialog), image pick → `ImageCropScreen` (4:3) → size checks, ban checks before opening the screen, and what `_tags` contains (localized labels of categories/diet + custom tags). Keep the existing controllers (`_titleController`, `_cookingTimeMinController`, `_IngredientItem`, `_StepItem`, …) — the new widgets wrap them, so drafts and submit keep working untouched.

Surgical: no changes outside this screen except the new files below, new l10n keys, and new tokens in `lib/theme/app_tokens.dart`. Split the 2.6k-line file only where it helps (e.g. `lib/recipes/create/` for the tag sheet, preview, stepper, ingredient row); say what you split.

## Tokens

Use `AppTokens` (light/dark) everywhere in this screen; no hard-coded colors except white-on-primary. Add three tokens:

| Token | Light | Dark | Use |
|---|---|---|---|
| field | `#F1F3F0` | `#222925` | text-field / stepper fill |
| primary | `#2E7D4F` | `#2E7D4F` | Publish button bg (white text ≥ 4.5:1; `fill` is too light for text) |
| dashed | `#B9C4BD` | `#3A4540` | dashed "add" borders |

Existing: `bg` page, `card` cards/bottom bar, `sheet` sheets, `ink`/`ink2` text, `line` borders, `brand` focus borders/progress, `brandInk` green text/icons, `soft` selected chips & badges, `scrim`.
Radii: section cards 20, fields/steppers 12, chips 17–18, buttons 14. Fields 48px high, 14px horizontal padding, 15px text, no outline; focused = 1.5px `brand` border on `card` bg.

## Screen structure

`Scaffold(bg)` → top bar → scrolling column (padding 8/16/120, 24 between sections) → bottom bar pinned above the keyboard-safe area.

### Top bar (56)
- Close (✕) 44×44 left → existing pop behaviour (incl. draft save on dispose).
- Title 18 w700: create = `createRecipe`, edit = `editRecipe` (existing keys).
- Right (create mode only): "✓ მონახაზი შენახულია" 12px `ink2`, shown after a draft save. Today drafts only save on dispose/app pause, so **add a debounced draft save** (≈2 s after the last edit, create mode only, only when `_hasMeaningfulData()`), reusing `_saveDraft`. Hidden until the first save.

### Section header (all six)
Row: 24px circle + title 16 w700 + optional caption right (12 `ink2`).
- Circle shows the section number on `soft`/`brandInk`; turns into a white ✓ on `brandInk` when the section is complete.
- Optional sections (1, 3, 4) show the caption `optional` ("არასავალდებულო"). Section 1 shows `"{n} ფოტო"` instead once it has photos; 5 shows the ingredient count; 6 shows `"{n} ნაბიჯი"`.
- Complete = 1: ≥1 image · 2: title non-empty · 3: any of time/servings/difficulty/cuisine set · 4: ≥1 tag · 5: ≥1 ingredient and every name filled · 6: ≥1 step and every step non-empty.

### 1 · ფოტოები (Photos)
- **Empty:** one 176-tall button, `card` bg, 1.5px dashed `dashed` border, radius 20: 52px `soft` tile with add-photo icon, "ფოტოების დამატება" 15 w700, "პირველი ფოტო გამოჩნდება გარეკანად" 13 `ink2`. Tap → existing `_pickImage`.
- **With photos:** first image 150×150 (radius 18) with "გარეკანი" badge (existing `Cover` label, translate it) bottom-left and a 32px ✕ (black 55%) top-right; remaining images + a dashed "+ დამატება" tile in a 2-column grid to its right (radius 14). More images than fit → wrap below in the same grid. Covers both `_existingImages` (edit) and `_selectedImages`. Keep existing max-count/size rules; hide the add tile at the max. No new drag-reorder.

### 2 · მთავარი (Basics) — card
- Label "სათაური *" (13 w600, asterisk `brandInk`), field hint "მაგ. აჭარული ხაჭაპური".
- Label "აღწერა", multiline field 96 tall, hint "რით არის ეს კერძი გამორჩეული?".

### 3 · დეტალები (Details) — card, 18 between rows
- **Time range:** label "მომზადების დრო" + right caption "წუთი". Two steppers side by side with an en-dash between. Stepper = 48-tall `field` pill: [−] 44px · value 16 w700 centered (tap value → type a number, numeric keyboard) · [+] 44px. Step 5; empty shows placeholder "მინ." / "მაქს." in `ink2`; + from empty → 5; − at 5 → empty. If min goes above max, bump max to min. Backed by the existing min/max controllers; `_submit` validation unchanged.
- **Servings:** label left, 150-wide stepper right; step 1, empty → 1, − at 1 → empty. Existing `_servingSizeController`.
- **Difficulty:** 3 equal buttons 52 tall: "●○○ მარტივი / ●●○ საშუალო / ●●● რთული" (dots 9px, label 13). Selected: `soft` bg, 1.5px `brand` border, `brandInk` w700; others `card` + 1px `line`, `ink2`. Keep today's tap/deselect behaviour.
- **Cuisine:** label, text field (existing controller) + wrap of quick chips from the existing `cuisineOptions` (selected = `soft`/`brandInk`), same toggle logic as now.

### 4 · თეგები (Tags) — card with wrapping chips
Selected tags as `soft` chips with a ✕ (26px target), then a dashed "+ თეგი" chip → **tag sheet**. Empty: only the "+ თეგი" chip and hint text "კატეგორია, დიეტა ან საკუთარი" in `ink2`.

**Tag sheet** (`showModalBottomSheet`, `sheet` bg, top radius 24, ~85% height, drag handle):
- Header: "თეგები" 18 w700 + text button "მზადაა · {n}" (`brandInk`) that closes.
- Search/add row: field "მოძებნე ან დაამატე საკუთარი" + 46px `soft` "+" button. Typing filters the chips below; submit/"+" adds a custom tag (existing add-tag rules: trim, no duplicates).
- Groups with 13 w600 `ink2` headings: **კატეგორია** (`recipeCategories`), **დიეტა** (`dietaryPreferences`), **საკუთარი** (custom tags in `_tags`, each with ✕). Chips 36 tall; selected = `soft` bg + ✓ + `brandInk` w700. Toggling updates `_tags` immediately (no cancel).
- Replaces the three horizontal scrollers and the inline tag input.

### 5 · ინგრედიენტები (Ingredients) — card
Rows are **collapsed** except the one being edited (max one expanded).
- **Collapsed row** (min 54, divider `line`): drag handle (existing reorder) · amount+unit 14 w700 `brandInk`, 64 wide (e.g. "500 გრ"; just the unit if no amount) · name 15 `ink`. Tap → expand it.
- **Expanded row** (inside the card, 10 margin, 1.5px `brand` border, radius 16, padding 12): name field (44 tall) + trash 44px; then amount field (72 wide, centered, decimal formatter as today) + **unit dropdown** (44 tall, radius 10, `field` fill, chevron; open = 1.5px `brand` border on `card`). Its menu is anchor-wide, `card` with a `line` border, 44-tall options; the chosen one is `soft` + `brandInk` w700 with a check. Implemented as a `MenuAnchor`, not a popup route, so opening it doesn't take focus out of the row and collapse it.
- New ingredient: dashed "+ ინგრედიენტის დამატება" (52 tall) appends a row expanded with the name focused. Collapsing a row (tap another row / outside / keyboard done) keeps it even if empty — `_submit` reports it.

**Unit presets store backend-recognised unit text.** The backend's nutrition calculator (`recipe_app_be/api/src/nutrition/nutrition.service.ts`, `UNIT_MAP` / `UNMEASURABLE_UNITS`) only understands certain tokens, so the preset value written to `unitController` must be exactly:
- ka: `გრ`, `კგ`, `მლ`, `ლიტრი`, `ჭიქა`, `ს/კ`, `ჩ/კ`, `ცალი`, `კბილი`, `გემოვნებით`
- en: `g`, `kg`, `ml`, `l`, `cup`, `tbsp`, `tsp`, `piece`, `clove`, `to taste`
- Option label = that text (the mock's "გ"/"ლ" are superseded). Choose the list by app language.
- Last option "სხვა" reveals a free-text unit field (existing controller) and focuses it. A unit that matches no preset (e.g. old recipes with "გრამი") shows as "სხვა" selected with the text filled.
- Selecting `გემოვნებით` / `to taste` may leave the amount empty.

### 6 · მომზადება (Method)
Numbered cards (radius 18, `card`, 1px `line`, padding 14): 28px `soft` number circle · multi-line field without a box (looks like text, 15/1.5) · drag handle (existing `_reorderSteps`). Focused card: 1.5px `brand` border, the number circle turns `brandInk`/white, and a "წაშლა" text button with trash icon appears at the bottom-right (error color). Below: dashed "+ ნაბიჯის დამატება" (52) appends a step and focuses it.

### Bottom bar (pinned)
`card` bg, top border `line`, padding 12/16/28 (+ safe area). Left: progress — "{done} / 3 სავალდებულო" 13 w600 and 3 equal 4px segments (`brand` when done, `line` otherwise) for title / ingredients / steps; when all done the text becomes "მზადაა გამოსაქვეყნებლად" in `brandInk`. Right: 48px outlined eye button → **Preview**, then the primary button (48 tall, radius 14, `primary`, white 15 w700): create = "გამოქვეყნება", edit = existing `saveChanges`.
- Primary looks muted (40% opacity) while required items are missing but **stays tappable**: tapping scrolls to the first incomplete required section, shows the existing validation message(s) inline under that section header (error color, 13px), and gives the field focus.
- While submitting: button shows a spinner, progress text is replaced by the existing upload status (`_uploadStatus`); server errors (`_error`) appear in a dismissible banner just above the bar instead of in the page.

## Preview screen (new, `RecipePreviewScreen`)
`RecipeDetailScreen` loads by `recipeId`, so build a light read-only screen from the in-memory form state (local files + existing image URLs):
- Top banner (`soft` bg, 56): back arrow → returns to the form; "გადახედვა" 15 w700 + "ასე დაინახავენ სხვები" 12 `brandInk`.
- Photo pager 250 tall with page dots; title 24 w800; author row (current user avatar + name); meta chips (time range, servings, difficulty, cuisine — only those set); description; tags; ingredients card ("{n} ინგრედიენტი", amount+unit in `brandInk` + name); numbered steps.
- Bottom bar: "რედაქტირება" (outlined, pops) + primary "გამოქვეყნება" (runs the same `_submit`, so return a result or pass a callback).
- Match the real recipe detail's look where cheap (fonts, spacing); no likes/comments/save/share.

## Localization
Reuse existing keys where the wording matches (`createRecipe`, `editRecipe`, `tags`, `ingredients`, `saveChanges`, `publishRecipe`, cuisine/category/diet labels, validation messages). Add getter + `en` + `ka` for the rest, e.g.: optional (Optional / არასავალდებულო), draftSaved (Draft saved / მონახაზი შენახულია), sectionPhotos (Photos / ფოტოები), sectionBasics (Basics / მთავარი), sectionDetails (Details / დეტალები), sectionMethod (Method / მომზადება), addPhotos (Add photos / ფოტოების დამატება), coverPhotoHint (The first photo will be the cover / პირველი ფოტო გამოჩნდება გარეკანად), coverBadge (Cover / გარეკანი), titleHint, descriptionHint, cookingTime (Cooking time / მომზადების დრო), minutesShort (min / წუთი), minHint/maxHint (min/max · მინ./მაქს.), addIngredient, addStep, otherUnit (Other… / სხვა…), addTag (Tag / თეგი), tagSearchHint, customTags (Your own / საკუთარი), tagsDone (Done · {n} / მზადაა · {n}), requiredProgress ({done} / {total} required), readyToPublish, preview (Preview / გადახედვა), previewSubtitle (This is how others will see it / ასე დაინახავენ სხვები), publish (Publish / გამოქვეყნება), edit, delete. Check for an existing key before adding each.

## Accessibility
44px minimum touch targets (chips may be 34–40 tall but need ≥44 hit area via padding/`MaterialTapTargetSize`). Semantics labels on icon-only buttons (close, preview, steppers "+/−" with the field name, ✕ on photos/tags, drag handles). Selected chips/difficulty expose selected state. Text scaling: rows grow, nothing clips.

## Acceptance checks
- `flutter analyze` passes with no new warnings.
- Light and dark match the tokens.
- Create: empty → fill everything → preview → publish; the API payload is identical to the old screen for the same input (compare a request before/after).
- Edit an existing recipe: all fields, existing images, tags (including custom), units prefill correctly; unknown units show under "სხვა"; save works, including image add/delete/reorder calls.
- Drafts: debounced save appears ("მონახაზი შენახულია"), kill the app mid-edit, reopen → "Draft found" restores everything.
- Validation: tapping Publish with missing title/ingredient/step scrolls to and highlights the first problem; min > max time still rejected.
- Unit presets write exactly the tokens listed above; nutrition for a test recipe with `ს/კ`, `ჭიქა`, `გრ` still computes on the backend.
- Steppers: +/− and typing both work; empty states as specified.
- Tag sheet: search filters, custom tag add/remove, selection count, categories/diet labels match the old ones in `_tags`.
- Final summary: what moved/split, what was deleted, anything left unused.
