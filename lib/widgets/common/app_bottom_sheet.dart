import "package:flutter/material.dart";

/// Shows a modal bottom sheet with standardized styling.
///
/// Provides consistent appearance across the app:
/// - Transparent background (sheets provide their own Container decoration)
/// - Scroll-controlled by default (allows sheets to size themselves)
///
/// Each sheet widget is responsible for wrapping its content in
/// `SafeArea(top: false)` inside its own Container decoration, ensuring
/// the bottom system navigation bar doesn't overlap content.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
