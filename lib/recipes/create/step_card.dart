import "package:flutter/material.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";

/// One method step: number circle · borderless multi-line text · drag handle.
/// While its text has focus the card gets a `brand` border, the number turns
/// solid and a Delete button shows at the bottom right.
class StepCard extends StatefulWidget {
  const StepCard({
    super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.onRemove,
  });

  /// Position in the list (0-based); shown as [index] + 1.
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onRemove;

  @override
  State<StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(StepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final focused = widget.focusNode.hasFocus;
    final error = Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: focused ? t.brand : t.line, width: focused ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: focused ? t.brandInk : t.soft, shape: BoxShape.circle),
                  child: Text(
                    "${widget.index + 1}",
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      // `card` = white in light mode, dark in dark mode.
                      color: focused ? t.card : t.brandInk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 15, height: 1.5, color: t.ink),
                      decoration: InputDecoration.collapsed(
                        hintText: l?.describeThisStep ?? "Describe this step",
                        hintStyle: TextStyle(fontSize: 15, height: 1.5, color: t.ink2),
                      ),
                    ),
                  ),
                ),
                Listener(
                  onPointerDown: (_) => FocusScope.of(context).unfocus(),
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: Semantics(
                      label: l?.dragToReorder ?? "Drag to reorder",
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.drag_indicator_rounded, size: 20, color: t.ink2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (focused)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4),
                  child: TextButton.icon(
                    onPressed: widget.onRemove,
                    style: TextButton.styleFrom(
                      foregroundColor: error,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      l?.delete ?? "Delete",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
