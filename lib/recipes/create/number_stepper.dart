import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";

/// 48-tall `field` pill: [−] · value · [+]. The value is a borderless number
/// field, so tapping it lets the user type. An empty controller shows
/// [placeholder].
///
/// [+] on empty sets [emptyStart] (or [step]); [−] that would reach 0 or
/// below empties the field. [onCommit] runs after a button tap and when typing
/// ends (focus lost or keyboard done); [onChanged] runs on every change.
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.controller,
    required this.step,
    required this.placeholder,
    required this.fieldName,
    this.emptyStart,
    this.focusNode,
    this.onChanged,
    this.onCommit,
  });

  final TextEditingController controller;
  final int step;
  final String placeholder;

  /// Read out with the +/− buttons, e.g. "Increase Cooking time (min)".
  final String fieldName;
  final int Function()? emptyStart;
  final FocusNode? focusNode;
  final VoidCallback? onChanged;
  final VoidCallback? onCommit;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final has = _focusNode.hasFocus;
    if (_hadFocus && !has) widget.onCommit?.call();
    _hadFocus = has;
    setState(() {});
  }

  int? get _value => int.tryParse(widget.controller.text.trim());

  void _set(int? value) {
    final text = value?.toString() ?? "";
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call();
    widget.onCommit?.call();
  }

  void _increment() {
    final v = _value;
    if (v == null) {
      _set(widget.emptyStart?.call() ?? widget.step);
    } else if (v + widget.step <= 9999) {
      _set(v + widget.step);
    }
  }

  void _decrement() {
    final v = _value;
    if (v == null) return;
    _set(v - widget.step <= 0 ? null : v - widget.step);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final focused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: focused ? t.card : t.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? t.brand : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            label: l?.decreaseValue(widget.fieldName) ?? "Decrease ${widget.fieldName}",
            onTap: _decrement,
          ),
          Expanded(
            child: Semantics(
              label: widget.fieldName,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                onChanged: (_) => widget.onChanged?.call(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
                decoration: InputDecoration.collapsed(
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: t.ink2),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            label: l?.increaseValue(widget.fieldName) ?? "Increase ${widget.fieldName}",
            onTap: _increment,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 44, height: 48, child: Icon(icon, size: 20, color: t.ink)),
      ),
    );
  }
}
