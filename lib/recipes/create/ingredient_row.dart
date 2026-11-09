import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "form_widgets.dart";

/// Unit presets, in Georgian. Each value is exactly a token the backend's
/// nutrition calculator understands (`UNIT_MAP` / `UNMEASURABLE_UNITS` in
/// recipe_app_be/api/src/nutrition/), so do not "fix" the spelling here.
const List<String> kaIngredientUnits = ["გრ", "კგ", "მლ", "ლიტრი", "ჭიქა", "ს/კ", "ჩ/კ", "ცალი", "კბილი", "გემოვნებით"];

/// Unit presets, in English. Same rule as [kaIngredientUnits].
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
/// and unit · name; tap to expand. Expanded: name + delete, then amount and a
/// unit dropdown whose last option, "Other", reveals a free-text unit field.
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

  /// Set when the user picks "Other" with an empty or preset unit; otherwise
  /// "Other" is derived from the unit text.
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

  void _pickUnit(String unit) {
    setState(() => _otherPicked = false);
    widget.unitController.text = unit;
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
                  child: _UnitDropdown(
                    units: units,
                    selected: isOther || unit.isEmpty ? null : unit,
                    isOther: isOther,
                    onUnit: _pickUnit,
                    onOther: () => _pickOther(units),
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

/// Unit picker: a field showing the chosen unit that opens a menu of [units]
/// with "Other" last.
///
/// It's a [MenuAnchor] (an overlay inside this widget's focus subtree) rather
/// than a popup route: a route would take focus out of the expanded row and
/// collapse it. Opening moves focus to the field itself, which closes the
/// keyboard so the menu has room while the row stays expanded.
class _UnitDropdown extends StatefulWidget {
  const _UnitDropdown({
    required this.units,
    required this.selected,
    required this.isOther,
    required this.onUnit,
    required this.onOther,
  });

  final List<String> units;

  /// The chosen preset, or null when the unit is empty or "Other".
  final String? selected;
  final bool isOther;
  final ValueChanged<String> onUnit;
  final VoidCallback onOther;

  @override
  State<_UnitDropdown> createState() => _UnitDropdownState();
}

class _UnitDropdownState extends State<_UnitDropdown> {
  final _controller = MenuController();
  final _focusNode = FocusNode(debugLabel: "Unit dropdown");
  bool _open = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isOpen) {
      _controller.close();
    } else {
      _focusNode.requestFocus();
      _controller.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final otherLabel = l?.otherUnit ?? "Other";
    final hint = l?.unit ?? "Unit";
    final shown = widget.isOther ? otherLabel : widget.selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MenuAnchor(
          controller: _controller,
          childFocusNode: _focusNode,
          consumeOutsideTap: true,
          onOpen: () => setState(() => _open = true),
          onClose: () {
            if (mounted) setState(() => _open = false);
          },
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(t.card),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(6),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: t.line),
              ),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
          ),
          menuChildren: [
            for (final u in widget.units)
              _UnitMenuItem(
                label: u,
                width: width,
                selected: !widget.isOther && widget.selected == u,
                onPressed: () => widget.onUnit(u),
              ),
            _UnitMenuItem(
              label: otherLabel,
              width: width,
              selected: widget.isOther,
              onPressed: widget.onOther,
            ),
          ],
          child: Semantics(
            button: true,
            expanded: _open,
            label: hint,
            value: shown,
            excludeSemantics: true,
            child: Focus(
              focusNode: _focusNode,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: _open ? t.card : t.field,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _open ? t.brand : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shown ?? hint,
                          style: shown == null
                              ? TextStyle(fontSize: 15, color: t.ink2)
                              : tokenFieldStyle(t).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: t.ink2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One option of [_UnitDropdown]: full menu width, 44 tall; the chosen one
/// is `soft` with `brandInk` w700 text and a check.
class _UnitMenuItem extends StatelessWidget {
  const _UnitMenuItem({required this.label, required this.width, required this.selected, required this.onPressed});

  final String label;
  final double width;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SizedBox(
      width: width,
      // Like DropdownMenu: items never take focus, so focus stays in the row.
      child: ExcludeFocus(
        child: MenuItemButton(
          onPressed: onPressed,
          requestFocusOnHover: false,
          trailingIcon: selected ? Icon(Icons.check_rounded, size: 18, color: t.brandInk) : null,
          style: MenuItemButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: selected ? t.soft : Colors.transparent,
            foregroundColor: selected ? t.brandInk : t.ink,
            iconColor: t.brandInk,
            overlayColor: t.brandInk,
          ),
          // Sized here, not via the button's textStyle, so the theme's font
          // family (from the button's default text style) is kept.
          child: Text(
            label,
            style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
