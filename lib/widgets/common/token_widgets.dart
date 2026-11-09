import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";

/// The app's chip, as on the Home feed's category row: a 36px pill with a
/// 44px tap target. Selected: `soft` with `brandInk` 700 text. Unselected:
/// `card` with a 1px `line` border and `ink2` 500 text.
///
/// [icon] goes before the label; [onDeleted] adds a trailing ✕ that removes
/// the chip (recent searches, pantry ingredients).
class TokenChip extends StatelessWidget {
  const TokenChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.onDeleted,
    this.deleteTooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final VoidCallback? onDeleted;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final fg = selected ? t.brandInk : t.ink2;

    return Semantics(
      button: onTap != null,
      selected: onTap != null ? selected : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: EdgeInsets.only(left: icon != null ? 10 : 14, right: onDeleted != null ? 4 : 14),
            decoration: BoxDecoration(
              color: selected ? t.soft : t.card,
              borderRadius: BorderRadius.circular(18),
              border: selected ? null : Border.all(color: t.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (onDeleted != null)
                  Semantics(
                    button: true,
                    label: deleteTooltip ?? MaterialLocalizations.of(context).deleteButtonTooltip,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDeleted,
                      child: SizedBox(
                        width: 32,
                        height: 36,
                        child: Icon(Icons.close_rounded, size: 16, color: fg),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of a single-choice list, as in the Home sort sheet: label (700
/// when selected) with an optional description, a radio ring on the right,
/// and a `line` divider below. [leading] shows an icon before the text.
class TokenRadioRow extends StatelessWidget {
  const TokenRadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.leading,
    this.showDivider = true,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: showDivider ? Border(bottom: BorderSide(color: t.line)) : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 22, color: selected ? t.brandInk : t.ink2),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: t.ink,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: TextStyle(fontSize: 13, color: t.ink2)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: t.brand, width: 7)
                      : Border.all(color: t.ink2.withValues(alpha: 0.6), width: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A `card` group with a 1px `line` border and radius 18, like the Profile
/// tab's library list. Children draw their own dividers.
class TokenGroup extends StatelessWidget {
  const TokenGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Material(type: MaterialType.transparency, child: Column(children: children)),
    );
  }
}

/// A row of a [TokenGroup], like the Profile tab's library rows: `ink2` icon,
/// 15px label (with an optional [description] below), then [value] in `ink2`
/// and a chevron, or a custom [trailing] (e.g. a switch). [destructive] turns
/// the icon and label to the theme's error color.
class TokenListRow extends StatelessWidget {
  const TokenListRow({
    super.key,
    required this.label,
    this.icon,
    this.description,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = false,
  });

  final IconData? icon;
  final String label;
  final String? description;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final error = Theme.of(context).colorScheme.error;
    final labelColor = destructive ? error : t.ink;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: t.line)) : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: destructive ? error : t.ink2),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: labelColor)),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(description!, style: TextStyle(fontSize: 13, color: t.ink2)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: t.ink2),
                    ),
                  ),
                ),
              if (onTap != null && !destructive) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: t.ink2),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Section label above a [TokenGroup], like the Profile tab's "Library":
/// 13px 600 `ink2`, sentence case.
class TokenSectionLabel extends StatelessWidget {
  const TokenSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Semantics(
        header: true,
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink2)),
      ),
    );
  }
}

/// The app's search box (Search tab, Saved): a 44px pill on `card` with a
/// 1px `line` border, a search icon, and a clear button once there is text.
class TokenSearchField extends StatelessWidget {
  const TokenSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called after the clear button empties the field.
  final VoidCallback? onCleared;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 20, color: t.ink2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: textInputAction,
              style: TextStyle(fontSize: 15, color: t.ink),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 15, color: t.ink2),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: 14)
                : IconButton(
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    onPressed: () {
                      controller.clear();
                      onChanged?.call("");
                      onCleared?.call();
                    },
                    icon: Icon(Icons.close_rounded, size: 18, color: t.ink2),
                  ),
          ),
        ],
      ),
    );
  }
}
