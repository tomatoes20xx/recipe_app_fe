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
///
/// `useSafeArea` keeps tall sheets (0.9–0.95 of the height) below the status
/// bar, as they were when the whole app sat inside one SafeArea.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
