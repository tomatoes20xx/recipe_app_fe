import "dart:math" as math;

import "package:flutter/material.dart";

import "../../constants/dietary_preferences.dart";
import "../../constants/recipe_categories.dart";
import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "form_widgets.dart";

/// Opens the tag picker: search/add field, then Category, Diet and the
/// user's own tags as chips. Every toggle goes straight to the caller (no
/// cancel); the sheet only re-reads [tags] to redraw.
///
/// [searchController] is also what [onAddCustom] reads, so the caller's
/// existing add-tag rules (trim, no duplicates, clear after adding) apply.
Future<void> showTagPickerSheet(
  BuildContext context, {
  required List<String> tags,
  required TextEditingController searchController,
  required void Function(String label) onToggle,
  required VoidCallback onAddCustom,
  required void Function(String tag) onRemove,
}) {
  final t = AppTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.sheet,
    barrierColor: t.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _TagPickerSheet(
      tags: tags,
      searchController: searchController,
      onToggle: onToggle,
      onAddCustom: onAddCustom,
      onRemove: onRemove,
    ),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({
    required this.tags,
    required this.searchController,
    required this.onToggle,
    required this.onAddCustom,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController searchController;
  final void Function(String label) onToggle;
  final VoidCallback onAddCustom;
  final void Function(String tag) onRemove;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_redraw);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  bool _matches(String label, String query) => query.isEmpty || label.toLowerCase().contains(query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final query = widget.searchController.text.trim();

    final categoryLabels = recipeCategories.map((c) => c.getLabel(l)).toList();
    final dietLabels = dietaryPreferences.map((d) => d.getLabel(l)).toList();
    final custom = widget.tags.where((tag) => !categoryLabels.contains(tag) && !dietLabels.contains(tag)).toList();

    final shownCategories = categoryLabels.where((c) => _matches(c, query)).toList();
    final shownDiets = dietLabels.where((d) => _matches(d, query)).toList();
    final shownCustom = custom.where((c) => _matches(c, query)).toList();

    void toggle(String label) {
      widget.onToggle(label);
      setState(() {});
    }

    void addCustom() {
      widget.onAddCustom();
      setState(() {});
    }

    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink2),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: chips),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          // About 85% of the screen, shrinking so the keyboard never pushes
          // the sheet past the top.
          height: math.max(0.0, math.min(media.size.height * 0.85, constraints.maxHeight - media.viewInsets.bottom)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l?.tags ?? "Tags",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: t.brandInk, minimumSize: const Size(44, 44)),
                      child: Text(
                        l?.tagsDone(widget.tags.length) ?? "Done · ${widget.tags.length}",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.searchController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => addCustom(),
                        style: tokenFieldStyle(t),
                        decoration: tokenInputDecoration(
                          t,
                          hint: l?.tagSearchHint ?? "Search or add your own",
                        ).copyWith(prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.ink2)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: l?.addTag ?? "Add a tag",
                      excludeSemantics: true,
                      child: Material(
                        color: t.soft,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: addCustom,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 46, height: 46, child: Icon(Icons.add_rounded, color: t.brandInk)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + media.padding.bottom),
                  children: [
                    if (shownCategories.isNotEmpty)
                      group(l?.tagCategory ?? "Category", [
                        for (final label in shownCategories)
                          TokenChip(
                            label: label,
                            selected: widget.tags.contains(label),
                            showCheck: true,
                            onTap: () => toggle(label),
                          ),
                      ]),
                    if (shownDiets.isNotEmpty)
                      group(l?.dietaryPreferences ?? "Dietary", [
                        for (final label in shownDiets)
                          TokenChip(
                            label: label,
                            selected: widget.tags.contains(label),
                            showCheck: true,
                            onTap: () => toggle(label),
                          ),
                      ]),
                    if (shownCustom.isNotEmpty)
                      group(l?.customTags ?? "Your own", [
                        for (final tag in shownCustom)
                          RemovableTagChip(
                            label: tag,
                            onRemove: () {
                              widget.onRemove(tag);
                              setState(() {});
                            },
                          ),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selected tag (`soft` chip, `brandInk` text) with a ✕ that removes it.
class RemovableTagChip extends StatelessWidget {
  const RemovableTagChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Semantics(
                selected: true,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.brandInk),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l?.removeTag(label) ?? "Remove $label",
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 34,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(Icons.close_rounded, size: 16, color: t.brandInk),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
