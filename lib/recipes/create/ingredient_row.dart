import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "form_widgets.dart";

/// Unit chips, in Georgian. Each value is exactly a token the backend's
/// nutrition calculator understands (`UNIT_MAP` / `UNMEASURABLE_UNITS` in
/// recipe_app_be/api/src/nutrition/), so do not "fix" the spelling here.
const List<String> kaIngredientUnits = ["გრ", "კგ", "მლ", "ლიტრი", "ჭიქა", "ს/კ", "ჩ/კ", "ცალი", "კბილი", "გემოვნებით"];

/// Unit chips, in English. Same rule as [kaIngredientUnits].
const List<String> enIngredientUnits = ["g", "kg", "ml", "l", "cup", "tbsp", "tsp", "piece", "clove", "to taste"];

List<String> ingredientUnitsFor(String languageCode) => languageCode == "ka" ? kaIngredientUnits : enIngredientUnits;

/// "500.0" → "500"; anything that isn't a whole number is shown as typed.
String formatQuantityText(String text) {
  final trimmed = text.trim();
  final v = double.tryParse(trimmed);
  if (v != null && v == v.roundToDouble()) return v.toInt().toString();
  return trimmed;
}

/// "500 გრ", or just the unit when there is no amount.
String ingredientAmountLabel(String quantity, String unit) => "${formatQuantityText(quantity)} ${unit.trim()}".trim();

/// Allows only digits with at most one decimal point.
class DecimalNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final regex = RegExp(r'^\d+\.?\d*$');
    return regex.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// One ingredient in the Ingredients card. Collapsed: drag handle · amount
/// and unit · name; tap to expand. Expanded: name + delete, then amount and
/// unit chips ("Other…" reveals a free-text unit).
///
/// The row collapses itself ([onCollapse]) when focus leaves it or on keyboard
/// done; the parent collapses it when another row expands or on a tap outside.
class IngredientRow extends StatefulWidget {
  const IngredientRow({
    super.key,
    required this.index,
    required this.nameController,
    required this.quantityController,
    required this.unitController,
    required this.nameFocusNode,
    required this.expanded,
    required this.showDivider,
    required this.onExpand,
    required this.onCollapse,
    required this.onRemove,
  });

  final int index;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final FocusNode nameFocusNode;
  final bool expanded;
  final bool showDivider;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onRemove;

  @override
  State<IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<IngredientRow> {
  final _quantityFocus = FocusNode();
  final _unitFocus = FocusNode();

  /// Set when the user picks "Other…" with an empty or chip unit; otherwise
  /// "Other…" is derived from the unit text.
  bool _otherPicked = false;

  @override
  void dispose() {
    _quantityFocus.dispose();
    _unitFocus.dispose();
    super.dispose();
  }

  void _collapse() {
    FocusScope.of(context).unfocus();
    widget.onCollapse();
  }

  void _pickUnit(String unit, bool selected) {
    setState(() => _otherPicked = false);
    widget.unitController.text = selected ? "" : unit;
  }

  void _pickOther(List<String> units) {
    if (units.contains(widget.unitController.text.trim())) {
      widget.unitController.clear();
    }
    setState(() => _otherPicked = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unitFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.expanded ? _buildExpanded(context) : _buildCollapsed(context);
  }

  Widget _buildCollapsed(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final name = widget.nameController.text.trim();
    final amount = ingredientAmountLabel(widget.quantityController.text, widget.unitController.text);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onExpand,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            border: widget.showDivider ? Border(bottom: BorderSide(color: t.line)) : null,
          ),
          child: Row(
            children: [
              Listener(
                onPointerDown: (_) => FocusScope.of(context).unfocus(),
                child: ReorderableDragStartListener(
                  index: widget.index,
                  child: Semantics(
                    label: l?.dragToReorder ?? "Drag to reorder",
                    child: SizedBox(
                      width: 44,
                      height: 54,
                      child: Icon(Icons.drag_indicator_rounded, size: 20, color: t.ink2),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  amount,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.brandInk),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                  child: Text(
                    name.isEmpty ? (l?.ingredientExample ?? "e.g., flour") : name,
                    style: TextStyle(fontSize: 15, color: name.isEmpty ? t.ink2 : t.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final units = ingredientUnitsFor(l?.locale.languageCode ?? "en");
    final unit = widget.unitController.text.trim();
    final isOther = _otherPicked || (unit.isNotEmpty && !units.contains(unit));

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (!hasFocus) widget.onCollapse();
      },
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.brand, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.nameController,
                    focusNode: widget.nameFocusNode,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _quantityFocus.requestFocus(),
                    style: tokenFieldStyle(t),
                    decoration: tokenInputDecoration(
                      t,
                      hint: l?.ingredientExample ?? "e.g., flour",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onRemove,
                  tooltip: l?.delete ?? "Delete",
                  icon: Icon(Icons.delete_outline_rounded, color: t.ink2),
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: widget.quantityController,
                    focusNode: _quantityFocus,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalNumberFormatter()],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _collapse(),
                    style: tokenFieldStyle(t).copyWith(fontWeight: FontWeight.w700),
                    decoration: tokenInputDecoration(
                      t,
                      hint: l?.amountHint ?? "Qty",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      radius: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RightEdgeFade(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 32),
                        child: Row(
                          children: [
                            for (final u in units)
                              _UnitChip(
                                label: u,
                                selected: !isOther && unit == u,
                                onTap: () => _pickUnit(u, !isOther && unit == u),
                              ),
                            _UnitChip(
                              label: l?.otherUnit ?? "Other…",
                              selected: isOther,
                              onTap: () => _pickOther(units),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isOther) ...[
              const SizedBox(height: 10),
              TextField(
                controller: widget.unitController,
                focusNode: _unitFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _collapse(),
                style: tokenFieldStyle(t),
                decoration: tokenInputDecoration(
                  t,
                  hint: l?.unit ?? "Unit",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.brandInk : t.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  // `card` = white in light mode; dark text on the light-green
                  // dark-mode brandInk keeps the contrast.
                  color: selected ? t.card : t.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
