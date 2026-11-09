import "package:flutter/material.dart";

import "app_tokens.dart";

/// The app's text-field look: filled, no outline; focused = 1.5px `brand`
/// border on `card`; errors get a 1.5px error border. 14px horizontal padding.
///
/// The fill follows the layering rule in [AppTokens]: `field` for a field
/// inside a card, section, sheet or dialog (the default), `card` for a field
/// sitting directly on the page background ([onPage]).
///
/// Add a label or icons with `copyWith`.
InputDecoration tokenInputDecoration(
  AppTokens t, {
  String? hint,
  EdgeInsetsGeometry? contentPadding,
  double radius = 12,
  bool onPage = false,
}) {
  final shape = OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none);
  OutlineInputBorder outlined(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: 1.5),
      );
  final rest = onPage ? t.card : t.field;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.ink2, fontSize: 15, fontWeight: FontWeight.w400),
    filled: true,
    fillColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.focused) ? t.card : rest),
    isDense: true,
    contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: shape,
    enabledBorder: shape,
    disabledBorder: shape,
    focusedBorder: outlined(t.brand),
    errorBorder: outlined(t.danger),
    focusedErrorBorder: outlined(t.danger),
  );
}

/// Text style of fields that use [tokenInputDecoration].
TextStyle tokenFieldStyle(AppTokens t) => TextStyle(fontSize: 15, color: t.ink, height: 1.3);
